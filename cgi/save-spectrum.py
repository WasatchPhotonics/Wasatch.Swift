#!/usr/bin/python
################################################################################
#                              save-spectrum.py                                #
################################################################################
#                                                                              #
#  DESCRIPTION:  A CGI (yeah) script to capture data sent by SiGDemo.          #
#                                                                              #
################################################################################

import datetime
import cgitb 
import json
import sys
import cgi
import os

base_directory = "/var/www/mco/public_html/sig"

def datestamp():
    return datetime.datetime.now().strftime('%Y-%m-%d') 

def timestamp():
    return datetime.datetime.now().strftime('%Y%m%d-%H%M%S') 

def saveMeasurement(measurement):
    # create or locate daily directory 
    today = datestamp()
    directory = "%s/%s" % (base_directory, today)
    if not os.path.isdir(directory):
        os.mkdir(directory)

    # extract metadata
    try:
        metadata = measurement["metadata"]
        serialNumber = metadata["serialNumber"]
    except:
        exitError("Missing metadata or serialNumber")

    # create filenames
    basename     = "%s-%s" % (timestamp(), serialNumber)
    pathnameJSON = "%s/%s" % (directory, basename + ".json")
    pathnameCSV  = "%s/%s" % (directory, basename + ".csv")

    # write JSON
    with open(pathnameJSON, "w") as f:
        f.write(json.dumps(measurement, sort_keys=True, indent=2))

    # write CSV
    with open(pathnameCSV, "w") as f: 
        if metadata is not None:
            for key in sorted(metadata):
                f.write("%s, %s\n" % (key, metadata[key]))
            f.write("\n")

        if measurement["spectrum"]:
            spectrum = measurement["spectrum"]
            if not spectrum:
                exitError("missing spectrum")

            wavelengths = spectrum["wavelengths"]
            wavenumbers = spectrum["wavenumbers"]
            raw         = spectrum["raw"]
            dark        = spectrum["dark"]
            reference   = spectrum["reference"]
            processed   = spectrum["processed"]

            if not raw:
                exitError("missing raw")

            pixels = len(raw)

            # header row
            fields = ["pixel"]
            if wavelengths:
                fields.append("wavelength")
            if wavenumbers:
                fields.append("wavenumbers")
            if raw:
                fields.append("raw")
            if dark:
                fields.append("dark")
            if reference:
                fields.append("reference")
            if processed:
                fields.append("processed")
            f.write(",".join(fields) + "\n")

            # data
            for i in range(pixels):
                row = [ str(i) ]
                if wavelengths:
                    row.append("%.2f" % wavelengths[i])
                if wavenumbers:
                    row.append("%.2f" % wavenumbers[i])
                if raw:
                    row.append("%.2f" % raw[i])
                if dark:
                    row.append("%.2f" % dark[i])
                if reference:
                    row.append("%.2f" % reference[i])
                if processed:
                    row.append("%.2f" % processed[i])
                f.write(",".join(row) + "\n")

    exitSuccess("measurement written to %s" % pathnameCSV)

def exitSuccess(message):
    print "Content-type:application/json\r\n\r\n"
    response = { "result": (message) }
    print(json.JSONEncoder().encode(response))

def exitError(message):
    print "Content-type:application/json\r\n\r\n"
    response = { "error": (message) }
    print(json.JSONEncoder().encode(response))

################################################################################
# Legacy -- keep these while testing new format
################################################################################

def saveCSV(spectrum):
    count = len(spectrum)
    filename = timestamp() + ".csv"
    pathname = base_directory + "/" + filename
    with open(pathname, "w") as f: 
        for i in range(count):
            f.write("%d,%.2f\n" % (i, spectrum[i]))

    print "Content-type:application/json\r\n\r\n"
    response = { "result": ("Spectrum of %d pixels saved as %s" % (count, filename)) }
    print(json.JSONEncoder().encode(response))

################################################################################
# main()
################################################################################

# parse POST input as JSON
data = json.load(sys.stdin)

# process as JSON
if data["measurement"]:
    saveMeasurement(data["measurement"])
elif data["spectrum"]:
    saveCSV(data["spectrum"])
else:
    sys.stderr.write(json.dumps(data))

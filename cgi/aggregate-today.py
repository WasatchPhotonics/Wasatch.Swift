#!/usr/bin/python
################################################################################
#                             aggregate-today.py                               #
################################################################################
#                                                                              #
#  DESCRIPTION:  Collate today's CSVs into a columnar merged file.             #
#                                                                              #
#  This script is run by root's crontab (as apache) on MCO every 5min.         #
#  An obvious improvement would be to make it more event-driven, such as       #
#  checking stat.mtime to see if any files had been added since the last       #
#  invocation / merged-* files had been written.                               #
#                                                                              #
################################################################################

import datetime
import sys
import os
import re

base_directory = "/var/www/mco/public_html/sig"

def datestamp():
    return datetime.datetime.now().strftime('%Y-%m-%d') 

def readSpectrum(filename):
    spectrum = []
    wavelengths = []
    wavenumbers = []

    today = datestamp()
    pathname = "%s/%s/%s" % (base_directory, today, filename)

    with open(pathname) as infile:
        readingData = False
        for line in infile:
            if readingData:
                # default format is pixel,wavelength,wavenumber,raw,processed
                tok = line.split(",")
                if len(tok) >= 4:
                    wavelengths.append(float(tok[1]))
                    wavenumbers.append(float(tok[2]))
                    spectrum.append(float(tok[3]))
                else:
                    break
            elif line.startswith("pixel,"):
                readingData = True
    return (spectrum, wavelengths, wavenumbers)

def collate(directory):
    serials = {}
    today = datestamp()

    # load all CSV filenames in this directory
    filenames = [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))]
    for filename in filenames:
        # format is YYYYMMDD-HHMMSS-SerialNumber.csv
        m = re.match(r'^\d{8}-\d{6}-(.*)\.csv$', filename)
        if not m:
            print "ignoring " + filename
            continue
        sn = m.group(1)
        if not sn in serials:
            serials[sn] = []
        serials[sn].append(filename)

    # process each serial number
    for sn in sorted(serials):
        filenames = sorted(serials[sn])

        # load all spectra for that serial number for this day
        # (only retain last wavelengths and wavenumbers)
        spectra = {}
        wavelengths = None
        wavenumbers = None
        for filename in filenames:
           (spectra[filename], wavelengths, wavenumbers) = readSpectrum(filename)
        pixels = len(wavelengths)

        outfilename = "merged-%s-%s.csv" % (today, sn)
        outpathname = "%s/%s/%s" % (base_directory, today, outfilename)
        with open(outpathname, "w") as outfile:
            # header row
            outfile.write("pixel,wavelength,wavenumber")
            for filename in filenames:
                m = re.match(r'^(\d{8}-\d{6})', filename)
                outfile.write("," + (m.group(1) if m else filename))
            outfile.write("\n")

            # data
            for i in range(pixels):
                outfile.write("%d,%.2f,%.2f" % (i, wavelengths[i], wavenumbers[i]))
                for filename in filenames:
                    outfile.write(",%.2f" % spectra[filename][i]);
                outfile.write("\n")

################################################################################
# main()
################################################################################

today = datestamp()
directory = "%s/%s" % (base_directory, today)
if os.path.isdir(directory):
    collate(directory)

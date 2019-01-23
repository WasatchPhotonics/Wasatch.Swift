.PHONY: docs cloc

cloc:
	@cloc --include-lang=Swift .

docs:
	@( cd SiGDemo && jazzy --min-acl private )
	@rsync --archive --progress SiGDemo/docs/ mco.wasatchphotonics.com:/var/www/mco/public_html/doc/SiGDemo

.PHONY: docs cloc

cloc:
	@cloc --include-lang=Swift .

docs:
	@( cd SiGDemo && jazzy --min-acl private )

SGREP(1)

##NAME
	sgrep - efficiently search large ordered files

##SYNOPSIS

	sgrep -v SEARCH_AREA_PATTERN_START SEARCH_AREA_PATTERN_END PATTERN FILE

##DESCRIPTION

	<B>Sgrep</B> searches a large ordered FILE where all lines start with some key marker (e.g., a leading timestamp in a log file), limiting its search to an area bounded by the keys SEARCH_AREA_PATTERN_BEGIN and SEARCH_AREA_PATTERN_END, looking for PATTERN.  Sgrep uses a binary search to avoid the performance hit of sequentially searching the entire file as grep would normally do.

##OPTIONS
	-v verbose mode

##EXAMPLES
	
	sgrep 20160303120205 20160303120215 /path/to/some/file /private/artifactory/logs/request.log

In this case sgrep searches the artifactory log file /private/artifactory/logs/request.log for lines matching /path/to/some/file, but only looks in those lands bounded by the timestamps 20160303120205 and 20160303120215.
config.weblog_2_tests.calibrate_and_test

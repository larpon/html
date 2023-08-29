// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
import html

fn test_parser_beautify() {
	messy_html := '<!DOCTYPE html><hTmL lang="en"><head><!-- comment --><title>Test</title><meta charset="UTF-8"/><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/></head><body></body></html>'

	pretty_html := html.beautify(messy_html)

	assert pretty_html == r'<!doctype html>
<html lang="en">
	<head>
		<!-- comment -->
		<title>
			Test
		</title>
		<meta charset="utf-8"/>
		<meta http-equiv="content-type" content="text/html; charset=utf-8"/>
	</head>
	<body>
	</body>
</html>
'
}

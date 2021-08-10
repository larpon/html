// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
import os
import html

fn test_parser_all() {
	// Re-use the parser instance for speed
	mut p := html.new_parser()

	mut path := ''

	test_data_path := os.join_path(os.dir(@FILE), 'data')

	dev_test_files := ['berlingske.dk.html', 'big.string.html', 'small.html', 'random.html']
	for test_file in dev_test_files {
		path = os.join_path(test_data_path, test_file)
		eprintln(@MOD + '.' + @FN + ' parsing "$path"')
		html.parse(mut p, path)
	}

	//path = os.join_path(test_data_path, 'small.html')
	//eprintln(@MOD + '.' + @FN + ' parsing "$path"')
	//html.parse(mut p, path)
	// TODO make this pass
	//assert p.raw() == os.read_file(path) or { panic(err) }

	path = os.join_path(test_data_path, 'html-sanitizer-testbed', 'testcases')
	test_files := os.walk_ext(path, 'html')
	for test_file in test_files {
		// One of the files in test-suite is zero, in which case the parser will, rightfully, panic. Just skip it.
		if os.file_size(test_file) == 0 {
			eprintln(@MOD + '.' + @FN + '"$path" is 0 in size. Skipping')
			continue
		}
		eprintln(@FN + ' parsing "$test_file"')
		html.parse(mut p, test_file)
	}

	base_path := os.join_path(test_data_path, 'web-platform-tests', 'html', 'syntax',
		'parsing')
	fs := os.ls(base_path) or { panic(err) }
	for f in fs {
		path = os.join_path(base_path, f)
		eprintln(@MOD + '.' + ' parsing "$path"')
		html.parse(mut p, path)
	}

	// NOTE kept for debug purposes
	// println(p.tokens())
	// println(p.raw())

	// Parser hasn't paniced if we reach this point
	assert true
}

fn test_parser_raw() {
	html_input := '<!DOCTYPE html>
<html lang="en">
  <head>
  <!-- comment -->
  <title>Test</title>
  <meta charset="UTF-8"/><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  </head>
  <body></body>
</html>'

	mut p := html.new_parser()
	html.parse(mut p, html_input)

	// Successful parsing and the input string is equal to the parsed output
	assert p.raw() == r'<!DOCTYPE html>
<html lang="en">
  <head>
  <!-- comment -->
  <title>Test</title>
  <meta charset="UTF-8"/><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  </head>
  <body></body>
</html>'
}

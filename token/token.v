// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module token

pub struct Token {
pub:
	kind Kind   // the token number/enum; for quick comparisons
	lit  string // literal representation of the token
	line int    // the line number in the source where the token occured
	pos  int    // the position of the token in input
	// idx    int // the index of the token
}

pub enum Kind {
	doctype
	tag_start
	tag_end
	comment
	whitespace
	character
	cdata
	null
	eof
}

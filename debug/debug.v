// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module debug

@[if debug]
pub fn info(id string, message string) {
	eprintln(id + ' ' + message)
}

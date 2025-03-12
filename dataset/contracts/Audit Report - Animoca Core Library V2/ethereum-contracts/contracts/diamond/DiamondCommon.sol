// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
pragma experimental ABIEncoderV2;

struct Facet {
    address facet;
    bytes4[] selectors;
}

enum FacetCutAction {
    ADD,
    REPLACE,
    REMOVE
}
// Add=0, Replace=1, Remove=2

struct FacetCut {
    address facet;
    FacetCutAction action;
    bytes4[] selectors;
}

struct Initialization {
    address target;
    bytes data;
}

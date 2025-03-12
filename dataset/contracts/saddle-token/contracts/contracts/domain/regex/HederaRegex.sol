// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HederaRegex {
    struct State {
        bool accepts;
        function(bytes1) internal pure returns (State memory) func;
    }

    string public constant regex = "0\\.0\\.[0-9]{1,6}";

    function s0(bytes1 c) internal pure returns (State memory) {
        c = c;
        return State(false, s0);
    }

    function s1(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint == 48) {
            return State(false, s2);
        }

        return State(false, s0);
    }

    function s2(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint == 46) {
            return State(false, s3);
        }

        return State(false, s0);
    }

    function s3(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint == 48) {
            return State(false, s4);
        }

        return State(false, s0);
    }

    function s4(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint == 46) {
            return State(false, s5);
        }

        return State(false, s0);
    }

    function s5(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s6);
        }

        return State(false, s0);
    }

    function s6(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s7);
        }

        return State(false, s0);
    }

    function s7(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s8);
        }

        return State(false, s0);
    }

    function s8(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s9);
        }

        return State(false, s0);
    }

    function s9(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s10);
        }

        return State(false, s0);
    }

    function s10(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if (_cint >= 48 && _cint <= 57) {
            return State(true, s11);
        }

        return State(false, s0);
    }

    function s11(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        // silence unused var warning
        _cint = _cint;

        return State(false, s0);
    }

    function matches(string memory input) public pure returns (bool) {
        State memory cur = State(false, s1);

        for (uint256 i = 0; i < bytes(input).length; i++) {
            bytes1 c = bytes(input)[i];

            cur = cur.func(c);
        }

        return cur.accepts;
    }
}

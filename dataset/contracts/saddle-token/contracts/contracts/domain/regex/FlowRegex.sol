// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlowRegex {
    struct State {
        bool accepts;
        function(bytes1) internal pure returns (State memory) func;
    }

    string public constant regex = "0x[0-9A-Fa-f]{16}";

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

        if (_cint == 120) {
            return State(false, s3);
        }

        return State(false, s0);
    }

    function s3(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s4);
        }

        return State(false, s0);
    }

    function s4(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s5);
        }

        return State(false, s0);
    }

    function s5(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s6);
        }

        return State(false, s0);
    }

    function s6(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s7);
        }

        return State(false, s0);
    }

    function s7(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s8);
        }

        return State(false, s0);
    }

    function s8(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s9);
        }

        return State(false, s0);
    }

    function s9(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s10);
        }

        return State(false, s0);
    }

    function s10(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s11);
        }

        return State(false, s0);
    }

    function s11(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s12);
        }

        return State(false, s0);
    }

    function s12(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s13);
        }

        return State(false, s0);
    }

    function s13(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s14);
        }

        return State(false, s0);
    }

    function s14(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s15);
        }

        return State(false, s0);
    }

    function s15(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s16);
        }

        return State(false, s0);
    }

    function s16(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s17);
        }

        return State(false, s0);
    }

    function s17(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(false, s18);
        }

        return State(false, s0);
    }

    function s18(bytes1 c) internal pure returns (State memory) {
        uint8 _cint = uint8(c);

        if ((_cint >= 48 && _cint <= 57) || (_cint >= 65 && _cint <= 70) || (_cint >= 97 && _cint <= 102)) {
            return State(true, s19);
        }

        return State(false, s0);
    }

    function s19(bytes1 c) internal pure returns (State memory) {
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

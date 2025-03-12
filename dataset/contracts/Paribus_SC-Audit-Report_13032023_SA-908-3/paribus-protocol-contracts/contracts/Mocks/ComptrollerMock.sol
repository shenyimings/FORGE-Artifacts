// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "../Comptroller/ComptrollerPart1.sol";
import "../Comptroller/ComptrollerPart2.sol";

contract ComptrollerMockBase is ComptrollerInterface, ComptrollerPart1, ComptrollerPart2 {
    constructor() public { }

    function isComptroller() external pure returns (bool) {
        return true;
    }
}

contract AllowingComptrollerMock is ComptrollerMockBase { // Comptroller with no business restrictions
    function mintAllowed(address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function mintVerify(address, address, uint, uint) external { }
    function redeemVerify(address, address, uint, uint) external { }
    function borrowVerify(address, address, uint) external { }
    function transferVerify(address, address, address, uint) external { }
    function redeemAllowed(address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function borrowAllowed(address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function transferAllowed(address, address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function repayBorrowAllowed(address, address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function repayBorrowVerify(address, address, address, uint, uint) external { }
    function liquidateBorrowVerify(address, address, address, address, uint, uint) external { }
    function seizeAllowed(address, address, address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
    function seizeVerify(address, address, address, address, uint) external { }
    function liquidateBorrowAllowed(address, address, address, address, uint) external returns (uint) { return uint(Error.NO_ERROR); }
}

contract DenyingComptrollerMock is ComptrollerMockBase {
    function mintAllowed(address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function mintVerify(address, address, uint, uint) external { }
    function redeemVerify(address, address, uint, uint) external { }
    function borrowVerify(address, address, uint) external { }
    function transferVerify(address, address, address, uint) external { }
    function redeemAllowed(address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function borrowAllowed(address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function transferAllowed(address, address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function repayBorrowAllowed(address, address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function repayBorrowVerify(address, address, address, uint, uint) external { }
    function liquidateBorrowVerify(address, address, address, address, uint, uint) external { }
    function seizeAllowed(address, address, address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
    function seizeVerify(address, address, address, address, uint) external { }
    function liquidateBorrowAllowed(address, address, address, address, uint) external returns (uint) { return uint(Error.REJECTION); }
}

contract ComptrollerStorageV2Mock is ComptrollerStorage {
    int foo;
    int bar;
}

contract ComptrollerPart1V2Mock is ComptrollerStorageV2Mock, ComptrollerPart1 {
    function getFoo() external view returns (int) {
        return foo;
    }

    function setFoo(int _foo) external {
        foo = _foo;
    }
}

contract ComptrollerPart2V2Mock is ComptrollerStorageV2Mock, ComptrollerPart2 {
    function getBar() external view returns (int) {
        return bar;
    }

    function setBar(int _bar) external {
        bar = _bar;
    }
}

contract ComptrollerV2Interface is ComptrollerPart1V2Mock, ComptrollerPart2V2Mock { }

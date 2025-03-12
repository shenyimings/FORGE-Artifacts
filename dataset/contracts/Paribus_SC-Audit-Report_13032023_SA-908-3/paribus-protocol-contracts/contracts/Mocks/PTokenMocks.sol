// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "../PToken/PErc20/PErc20Delegate.sol";
import "../PToken/PEther/PEtherDelegate.sol";

contract PTokenStorageV2Mock is PTokenStorage {
    int foo;
    int bar;
}

contract PErc20DelegateV2Mock is PErc20Delegate, PTokenStorageV2Mock { // that EXACT inheritance order is CRUCIAL here
    function getBar() external view returns (int) {
        return bar;
    }

    function setBar(int _bar) external {
        bar = _bar;
    }

    function getFoo() external view returns (int) {
        return foo;
    }

    function setFoo(int _foo) external {
        foo = _foo;
    }
}

contract PEtherStorageV2Mock is PTokenStorage {
    int foo;
    int bar;
}

contract PEtherDelegateV2Mock is PEtherDelegate, PEtherStorageV2Mock { // that EXACT inheritance order is CRUCIAL here
    function getBar() external view returns (int) {
        return bar;
    }

    function setBar(int _bar) external {
        bar = _bar;
    }

    function getFoo() external view returns (int) {
        return foo;
    }

    function setFoo(int _foo) external {
        foo = _foo;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract FacetMock {
    event FacetFunctionCalled();

    error RevertedWithMessage();

    function doSomething() external {
        emit FacetFunctionCalled();
    }

    function revertsWithoutMessage() external pure {
        // solhint-disable-next-line custom-errors, reason-string
        revert();
    }

    function revertsWithMessage() external pure {
        revert RevertedWithMessage();
    }

    // These functions are placeholders for tests to manipulate the selectorCount in different scenarios
    function a() external pure {}

    function b() external pure {}

    function c() external pure {}

    function d() external pure {}

    function e() external pure {}

    function f() external pure {}

    function g() external pure {}

    function h() external pure {}

    function i() external pure {}

    function j() external pure {}

    function k() external pure {}
}

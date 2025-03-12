// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable-next-line compiler-version
pragma solidity ^0.7.6;

interface IWAMPL {
    function wrapperToUnderlying(uint256 wamples) external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.7.5;

import './IERC20.sol';

interface IRING is IERC20 {
    function getCirculatingSupply() external view returns (uint256);

    function gonsForBalance(uint256 amount) external view returns (uint256);

    function balanceForGons(uint256 gons) external view returns (uint256);

    function returnMsgSender() external view returns (address);

    function index() external view returns (uint256);
}

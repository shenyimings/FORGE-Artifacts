// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IGame {
    function isPlayerStillPlaying() external returns (bool);

    function pause() external;

    function unpause() external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IDackieV3LmPoolDeveloper {
    function parameters()
    external
    view
    returns (address pool, address masterChef, address firstLMPool, address secondLMPool, address thirdLMPool);
}
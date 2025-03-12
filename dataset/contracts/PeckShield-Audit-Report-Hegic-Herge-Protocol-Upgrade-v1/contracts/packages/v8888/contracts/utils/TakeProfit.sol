pragma solidity ^0.8.3;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

import "../Interfaces/Interfaces.sol";
import "../OptionsManager/IOptionsManager.sol";

/**
 * @author 0mllwntrmt3
 * @title Hegic Protocol V8888 Exerciser Contract
 * @notice The contract that allows to automatically exercise options half an hour before expiration
 **/
contract ExerciserTakeProfit {
    IOptionsManager public immutable optionsManager;
    mapping(uint256 => uint256) public takeProfits;
    mapping(string => string) private mapContractsAddress;
    mapping(IHegicPool => bool) isPutPool;
    mapping(IHegicPool => bool) isCallPool;
    event TakeProfitSet(uint256 indexed optionId, uint256 price);

    constructor(
        IOptionsManager manager,
        IHegicPool[] memory callPool,
        IHegicPool[] memory putPool
    ) {
        optionsManager = manager;
        for (uint256 i = 0; i < callPool.length; i++) {
            isCallPool[IHegicPool(callPool[i])] = true;
        }
        for (uint256 i = 0; i < putPool.length; i++) {
            isPutPool[IHegicPool(putPool[i])] = true;
        }
    }

    function setTakeProfitPrice(uint256 optionId, uint256 price) external {
        require(
            optionsManager.isApprovedOrOwner(msg.sender, optionId),
            "the option does not belong to msg.sender"
        );
        takeProfits[optionId] = price;
        emit TakeProfitSet(optionId, price);
    }

    function getTakeProfitPrice(uint256 optionId)
        public
        view
        returns (uint256)
    {
        return takeProfits[optionId];
    }

    function _getPrices(IHegicPool pool, uint256 optionId)
        private
        returns (uint256 strike, uint256 latestPrice)
    {
        (, uint256 strike, , uint256 expired, , , ) = pool.options(optionId);
        (, int256 price, , , ) = pool.priceProvider().latestRoundData();
        uint256 latestPrice = uint256(price);
        require(
            takeProfits[optionId] != 0,
            "TakeProfit: Option holder should setTakeProfitPrice() before"
        );
        return (strike, latestPrice);
    }

    function takeProfitCall(uint256 optionId) external {
        IHegicPool pool = IHegicPool(optionsManager.tokenPool(optionId));
        (uint256 strike, uint256 latestPrice) = _getPrices(pool, optionId);
        require(isCallPool[pool], "TakeProfit: CALL wrong type option");
        require(
            latestPrice >= takeProfits[optionId],
            "TakeProfit: CALL Current price less than take price"
        );
        pool.exercise(optionId);
    }

    function takeProfitPut(uint256 optionId) external {
        IHegicPool pool = IHegicPool(optionsManager.tokenPool(optionId));
        (uint256 strike, uint256 latestPrice) = _getPrices(pool, optionId);
        require(isPutPool[pool], "TakeProfit: PUT wrong type option");
        require(
            latestPrice <= takeProfits[optionId],
            "TakeProfit: PUT Current price more than take price"
        );
        pool.exercise(optionId);
    }
}

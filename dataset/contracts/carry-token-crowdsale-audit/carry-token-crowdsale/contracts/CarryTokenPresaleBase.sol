// The Carry token and the tokensale contracts
// Copyright (C) 2018 Carry Protocol
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CarryToken.sol";

/**
 * @title CarryTokenPresaleCrowdsale
 * @dev The base contract for the Carry token presale.  (Note that it was
 * intended to be an abstract base contract for common things between
 * the token presale and the public token crowdsale both, but since
 * we decided to change the policy for the public crowdsale, so there is no
 * much common things between both.)
 */
contract CarryTokenPresaleBase is WhitelistedCrowdsale, CappedCrowdsale, Pausable {
    using SafeMath for uint256;

    uint256 constant maxGasPrice = 40000000000;  // 40 gwei

    // Individual min and max purchases.
    uint256 public individualMinPurchaseWei;
    uint256 public individualMaxCapWei;

    mapping(address => uint256) public contributions;

    constructor(
        address _wallet,
        CarryToken _token,
        uint256 _rate,
        uint256 _cap,
        uint256 _individualMinPurchaseWei,
        uint256 _individualMaxCapWei
    ) public CappedCrowdsale(_cap) Crowdsale(_rate, _wallet, _token) {
        individualMinPurchaseWei = _individualMinPurchaseWei;
        individualMaxCapWei = _individualMaxCapWei;
    }

    function _preValidatePurchase(
        address _beneficiary,
        uint256 _weiAmount
    ) internal whenNotPaused {
        // Prevent gas war among purchasers.
        require(
            tx.gasprice <= maxGasPrice,
            "Gas price is too expensive. Don't be competitive."
        );

        super._preValidatePurchase(_beneficiary, _weiAmount);
        uint256 contribution = contributions[_beneficiary];
        uint256 contributionAfterPurchase = contribution.add(_weiAmount);

        // If a contributor already has purchased a minimum amount, say 0.1 ETH,
        // then they can purchase once again with less than a minimum amount,
        // say 0.01 ETH, because they have already satisfied the minimum
        // purchase.
        require(
            contributionAfterPurchase >= individualMinPurchaseWei,
            "Sent ethers is not enough."
        );

        require(
            contributionAfterPurchase <= individualMaxCapWei,
            "Total ethers you've purchased is too much."
        );
    }

    function _updatePurchasingState(
        address _beneficiary,
        uint256 _weiAmount
    ) internal {
        super._updatePurchasingState(_beneficiary, _weiAmount);
        contributions[_beneficiary] = contributions[_beneficiary].add(
            _weiAmount
        );
    }
}

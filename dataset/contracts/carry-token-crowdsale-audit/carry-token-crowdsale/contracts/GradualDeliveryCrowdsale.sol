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

import "openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

/**
 * @title GradualDeliveryCrowdsale
 * @dev Crowdsale that does not deliver tokens to a beneficiary immediately
 * after they have just purchased, but instead partially delivers tokens through
 * several times when the contract owner calls deliverTokensInRatio() method.
 * Note that it also provides methods to selectively refund some purchases.
 */
contract GradualDeliveryCrowdsale is Ownable, Crowdsale {
    using SafeMath for uint;
    using SafeMath for uint256;

    mapping(address => uint256) public balances;
    address[] beneficiaries;
    mapping(address => uint256) public refundedDeposits;

    event TokenDelivered(address indexed beneficiary, uint256 tokenAmount);
    event RefundDeposited(
        address indexed beneficiary,
        uint256 tokenAmount,
        uint256 weiAmount
    );
    event Refunded(
        address indexed beneficiary,
        address indexed receiver,
        uint256 weiAmount
    );

    /**
     * @dev Deliver only the given ratio of tokens to the beneficiaries.
     * For example, where there are two beneficiaries of each balance 90 CRE and
     * 60 CRE, deliverTokensInRatio(1, 3) delivers each 30 CRE and 20 CRE to
     * them.  In the similar way, deliverTokensInRatio(1, 1) delivers
     * their entire tokens.
     */
    function deliverTokensInRatio(
        uint256 _numerator,
        uint256 _denominator
    ) external onlyOwner {
        _deliverTokensInRatio(
            _numerator,
            _denominator,
            0,
            beneficiaries.length
        );
    }

    /**
     * @dev It's mostly same to deliverTokensInRatio(), except it processes
     * only a particular range of the list of beneficiaries.
     */
    function deliverTokensInRatioOfRange(
        uint256 _numerator,
        uint256 _denominator,
        uint _startIndex,
        uint _endIndex
    ) external onlyOwner {
        require(
            _startIndex < _endIndex,
            "_startIndex must be less than _endIndex"
        );
        _deliverTokensInRatio(_numerator, _denominator, _startIndex, _endIndex);
    }

    function _deliverTokensInRatio(
        uint256 _numerator,
        uint256 _denominator,
        uint _startIndex,
        uint _endIndex
    ) internal {
        require(_denominator > 0, "_denominator cannot be less than 1.");
        require(
            _numerator <= _denominator,
            "_numerator cannot be greater than _denominator."
        );
        uint endIndex = _endIndex;
        if (endIndex > beneficiaries.length) {
            endIndex = beneficiaries.length;
        }
        for (uint i = _startIndex; i < endIndex; i = i.add(1)) {
            address beneficiary = beneficiaries[i];
            uint256 balance = balances[beneficiary];
            if (balance > 0) {
                uint256 amount = balance.mul(_numerator).div(_denominator);
                balances[beneficiary] = balance.sub(amount);
                _deliverTokens(beneficiary, amount);
                emit TokenDelivered(beneficiary, amount);
            }
        }
    }

    function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
    ) internal {
        if (_tokenAmount > 0) {
            if (balances[_beneficiary] <= 0) {
                beneficiaries.push(_beneficiary);
            }
            balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
        }
    }
    /**
     * @dev Refund the given ether to a beneficiary.  It only can be called by
     * either the contract owner or the wallet (i.e., Crowdsale.wallet) address.
     * The only amount of the ether sent together in a transaction is refunded.
     */
    function depositRefund(address _beneficiary) public payable {
        require(
            msg.sender == owner || msg.sender == wallet,
            "No permission to access."
        );
        uint256 weiToRefund = msg.value;
        require(
            weiToRefund <= weiRaised,
            "Sent ethers is higher than even the total raised ethers."
        );
        uint256 tokensToRefund = _getTokenAmount(weiToRefund);
        uint256 tokenBalance = balances[_beneficiary];
        require(
            tokenBalance >= tokensToRefund,
            "Sent ethers is higher than the ethers _beneficiary has purchased."
        );
        weiRaised = weiRaised.sub(weiToRefund);
        balances[_beneficiary] = tokenBalance.sub(tokensToRefund);
        refundedDeposits[_beneficiary] = refundedDeposits[_beneficiary].add(
            weiToRefund
        );
        emit RefundDeposited(_beneficiary, tokensToRefund, weiToRefund);
    }

    /**
     * @dev Receive one's refunded ethers in the deposit.  It can be called by
     * either the contract owner or the beneficiary of the refund.
     * The deposited ether is sent to only the beneficiary regardless it is
     * called by which address, either the contract owner or the beneficary.
     * It usually can be systemically called together right after
     * depositRefund() is called.
     */
    function receiveRefund(address _beneficiary) public {
        require(
            msg.sender == owner || msg.sender == _beneficiary,
            "No permission to access."
        );
        _transferRefund(_beneficiary, _beneficiary);
    }

    /**
     * @dev Similar to receiveRefund() except that it cannot be called by
     * even the contract owner, but only the beneficiary of the refund.
     * It also takes an additional parameter, a wallet address to receiver
     * the deposited (refunded) ethers.
     * The main purpose of this method is to receive the refunded ethers
     * to the other address than the beneficiary address.  Usually after
     * depositRefund() is called, receiveRefund() is immediately executed
     * together by the automated system, but there could be cases that
     * the the beneficiary address is a smart contract and it causes
     * the transaction to transfer ethers in any reason.  In such cases,
     * the deposit beneficiary need to "pull" his ethers to his another
     * wallet address by calling this method.
     */
    function receiveRefundTo(address _beneficiary, address _wallet) public {
        require(msg.sender == _beneficiary, "No permission to access.");
        _transferRefund(_beneficiary, _wallet);
    }

    function _transferRefund(address _beneficiary, address _wallet) internal {
        uint256 depositedWeiAmount = refundedDeposits[_beneficiary];
        require(depositedWeiAmount > 0, "_beneficiary has never purchased.");
        refundedDeposits[_beneficiary] = 0;
        _wallet.transfer(depositedWeiAmount);
        emit Refunded(_beneficiary, _wallet, depositedWeiAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./PoolStorage.sol";
import "./PoolToken.sol";
import "./PoolLoan.sol";
import "./Asset.sol";

contract Pool is PoolStorage, Structured, Loan {
    using SafeMath for uint256;

    event Lend(address indexed lender, uint256 _amount);
    event Borrowed(uint256 indexed loanId, uint256 _amount);
    event Repayed(uint256 indexed loanId, uint256 _amount);
    event Withdrawn(address indexed lender, uint256 _amount);
    event AssetUnlocked(uint256 indexed tokenId);

    constructor(
        string memory name_,
        string memory structureType_,
        address stableCoin_,
        uint256 minDeposit_
    ) {
        require(isStructured(structureType_));

        name = name_;
        minDeposit = minDeposit_;
        structureType = structureType_;
        stableCoin = stableCoin_;

        ERC20 token = ERC20(stableCoin);
        lpToken = new PoolToken("PoolToken", token.symbol());
    }

    function lend(uint256 amount) external returns (bool success) {
        require(amount >= minDeposit, "lend: Amount lower than minDeposit");
        require(_transferTokens(msg.sender, address(this), amount));

        balances[msg.sender] += amount;
        totalDeposited += amount;
        lockedTokens[msg.sender] += amount;
        emit Lend(msg.sender, amount);

        lpToken.mint(msg.sender, amount);
        return true;
    }

    function withdraw(uint256 _tokenAmount) external isAvailable(_tokenAmount) returns (bool success) {
        require(_tokenAmount > 0, "withdraw: Amount lower than 0");
        require(lockedTokens[msg.sender] >= _tokenAmount, "withdraw: amount higher than owned tokens");

        totalDeposited -= _tokenAmount;
        balances[msg.sender] -= _tokenAmount;
        lockedTokens[msg.sender] -= _tokenAmount;

        lpToken.burnFrom(msg.sender, _tokenAmount);
        emit Withdrawn(msg.sender, _tokenAmount);
        
        return _transferTokens(address(this), msg.sender, _tokenAmount);
    }

    function createLoan(address nftAddress, uint256 tokenId) external returns (bool success) {
        uint256 loanId = createCreditLineInternal(nftAddress, msg.sender, tokenId);

        loans[loanId] = LoanStruct(0, nftAddress);
        return true;
    }

    function closeLoan(uint256 loanId) external returns (bool success) {
        Loan.CreditLine storage creditLine = creditLines[loanId];
        require(creditLine.debt == 0, "closeLoan: Loan has debt");
        require(creditLine.isClosed == false, "closeLoan: Loan is already closed");

        require(closeCreditLineInternal(loanId));

        Asset nftFactory = Asset(loans[loanId].nftFactory);
        nftFactory.markAsRedeemed(creditLine.lockedAsset);
        return true;
    }

    function unlockAsset(uint256 loanId) external returns (bool success) {
        Loan.CreditLine storage creditLine = creditLines[loanId];
        require(creditLine.isClosed, "closeLoan: Loan is not closed");

        Asset nftFactory = Asset(loans[loanId].nftFactory);

        nftFactory.transferFrom(address(this), msg.sender, creditLine.lockedAsset);
        emit AssetUnlocked(creditLine.lockedAsset);
        return true;
    }

    function borrow(uint256 loanId, uint256 amount) external isAvailable(amount) returns (bool success) {
        Loan.CreditLine storage creditLine = creditLines[loanId];

        uint256 availableAmountForLoan = creditLine.amount.sub(creditLine.debt);
        require(availableAmountForLoan >= amount, "borrow: insufficient available amount");
        require(borrowInternal(loanId, msg.sender, amount));
        
        totalBorrowed += amount;
        loans[loanId].borrowedAmount += amount;

        emit Borrowed(loanId, amount);
        return _transferTokens(address(this), msg.sender, amount);
    }

    function repay(uint256 loanId, uint256 amount) external returns (bool success) { 
        Loan.CreditLine storage creditLine = creditLines[loanId];

        require(amount > 0, "repay: amount must be greater than 0");
        require(creditLine.debt>= amount, "repay: amount higher than debt");
        require(repayInternal(loanId, msg.sender, amount));

        emit Repayed(loanId, amount);

        totalBorrowed -= amount;
        loans[loanId].borrowedAmount -= amount;


        if (creditLine.debt == 0) {
            require(this.closeLoan(loanId));
        }
        return _transferTokens(msg.sender, address(this), amount);
    }


    function _transferTokens(address _from, address _to, uint256 _tokenAmount) internal returns (bool success) {
        ERC20 token = ERC20(stableCoin);
        require(token.balanceOf(_from) >= _tokenAmount, "ERC20: Insufficient funds");
        if (_from == address(this)) {
            require(token.transfer(_to, _tokenAmount), "ERC20: Failed to transfer");
        } else {
            require(token.transferFrom(_from, _to, _tokenAmount), "ERC20: Transfer failed");
        }
        return true;
    }
}

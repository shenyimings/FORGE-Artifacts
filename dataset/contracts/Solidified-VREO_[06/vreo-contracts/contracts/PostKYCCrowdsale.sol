pragma solidity 0.4.24;

import "../node_modules/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "../node_modules/zeppelin-solidity/contracts/crowdsale/Crowdsale.sol";


/// @title PostKYCCrowdsale
/// @author Sicos et al.
contract PostKYCCrowdsale is Crowdsale, Ownable {

    struct Investment {
        bool isVerified;         // wether or not the investor passed the KYC process
        uint totalWeiInvested;   // total invested wei regardless of verification state
        // amount of token an unverified investor bought. should be zero for verified investors
        uint pendingTokenAmount;
    }

    // total amount of wei held by unverified investors should never be larger than this.balance
    uint public pendingWeiAmount = 0;

    // maps investor addresses to investment information
    mapping(address => Investment) public investments;

    /// @dev Log entry on investor verified
    /// @param investor the investor's Ethereum address
    event InvestorVerified(address investor);

    /// @dev Log entry on tokens delivered
    /// @param investor the investor's Ethereum address
    /// @param amount token amount delivered
    event TokensDelivered(address investor, uint amount);

    /// @dev Log entry on investment withdrawn
    /// @param investor the investor's Ethereum address
    /// @param value the wei amount withdrawn
    event InvestmentWithdrawn(address investor, uint value);

    /// @dev Verify investors
    /// @param _investors list of investors' Ethereum addresses
    function verifyInvestors(address[] _investors) public onlyOwner {
        for (uint i = 0; i < _investors.length; ++i) {
            address investor = _investors[i];
            Investment storage investment = investments[investor];

            if (!investment.isVerified) {
                investment.isVerified = true;

                emit InvestorVerified(investor);

                uint pendingTokenAmount = investment.pendingTokenAmount;
                // now we issue tokens to the verfied investor
                if (pendingTokenAmount > 0) {
                    investment.pendingTokenAmount = 0;

                    _forwardFunds(investment.totalWeiInvested);
                    _deliverTokens(investor, pendingTokenAmount);

                    emit TokensDelivered(investor, pendingTokenAmount);
                }
            }
        }
    }

    /// @dev Withdraw investment
    /// @dev Investors that are not verified can withdraw their funds
    function withdrawInvestment() public {
        Investment storage investment = investments[msg.sender];

        require(!investment.isVerified);

        uint totalWeiInvested = investment.totalWeiInvested;

        require(totalWeiInvested > 0);

        investment.totalWeiInvested = 0;
        investment.pendingTokenAmount = 0;

        pendingWeiAmount = pendingWeiAmount.sub(totalWeiInvested);

        msg.sender.transfer(totalWeiInvested);

        emit InvestmentWithdrawn(msg.sender, totalWeiInvested);

        assert(pendingWeiAmount <= address(this).balance);
    }

    /// @dev Prevalidate purchase
    /// @param _beneficiary the investor's Ethereum address
    /// @param _weiAmount the wei amount invested
    function _preValidatePurchase(address _beneficiary, uint _weiAmount) internal {
        // We only want the msg.sender to buy tokens
        require(_beneficiary == msg.sender);

        super._preValidatePurchase(_beneficiary, _weiAmount);
    }

    /// @dev Process purchase
    /// @param _beneficiary the investor's Ethereum address
    /// @param _tokenAmount the token amount purchased
    function _processPurchase(address _beneficiary, uint _tokenAmount) internal {
        Investment storage investment = investments[msg.sender];
        investment.totalWeiInvested = investment.totalWeiInvested.add(msg.value);

        if (investment.isVerified) {
            // If the investor's KYC is already verified we issue the tokens imediatly
            _deliverTokens(_beneficiary, _tokenAmount);
            emit TokensDelivered(_beneficiary, _tokenAmount);
        } else {
            // If the investor's KYC is not verified we store the pending token amount
            investment.pendingTokenAmount = investment.pendingTokenAmount.add(_tokenAmount);
            pendingWeiAmount = pendingWeiAmount.add(msg.value);
        }
    }

    /// @dev Forward funds
    function _forwardFunds() internal {
        // Ensure the investor was verified, i.e. his purchased tokens were delivered,
        // before forwarding funds.
        if (investments[msg.sender].isVerified) {
            super._forwardFunds();
        }
    }

    /// @dev Forward funds
    /// @param _weiAmount the amount to be transfered
    function _forwardFunds(uint _weiAmount) internal {
        pendingWeiAmount = pendingWeiAmount.sub(_weiAmount);
        wallet.transfer(_weiAmount);
    }

    /// @dev Postvalidate purchase
    /// @param _beneficiary the investor's Ethereum address
    /// @param _weiAmount the amount invested
    function _postValidatePurchase(address _beneficiary, uint _weiAmount) internal {
        super._postValidatePurchase(_beneficiary, _weiAmount);
        // checking invariant
        assert(pendingWeiAmount <= address(this).balance);
    }

}

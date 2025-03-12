pragma solidity 0.4.24;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "../node_modules/zeppelin-solidity/contracts/crowdsale/distribution/FinalizableCrowdsale.sol";
import "../node_modules/zeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "./PostKYCCrowdsale.sol";
import "./VreoToken.sol";


/// @title VreoTokenSale
/// @author Sicos et al.
contract VreoTokenSale is PostKYCCrowdsale, FinalizableCrowdsale, MintedCrowdsale {

    // Maxmimum number of tokens sold in Presale+Iconiq+Vreo sales
    uint public constant TOTAL_TOKEN_CAP_OF_SALE = 450000000e18;  // = 450.000.000 e18

    // Extra tokens minted upon finalization
    uint public constant TOKEN_SHARE_OF_TEAM     =  85000000e18;  // =  85.000.000 e18
    uint public constant TOKEN_SHARE_OF_ADVISORS =  58000000e18;  // =  58.000.000 e18
    uint public constant TOKEN_SHARE_OF_LEGALS   =  57000000e18;  // =  57.000.000 e18
    uint public constant TOKEN_SHARE_OF_BOUNTY   =  50000000e18;  // =  50.000.000 e18

    // Extra token percentages
    uint public constant BONUS_PCT_IN_ICONIQ_SALE       = 30;  // TBD
    uint public constant BONUS_PCT_IN_VREO_SALE_PHASE_1 = 20;
    uint public constant BONUS_PCT_IN_VREO_SALE_PHASE_2 = 10;

    // Date/time constants
    uint public constant ICONIQ_SALE_OPENING_TIME   = 1530432000;  // 2018-07-01 10:00:00 CEST
    uint public constant ICONIQ_SALE_CLOSING_TIME   = 1531598400;  // 2018-07-14 22:00:00 CEST
    uint public constant VREO_SALE_OPENING_TIME     = 1532160000;  // 2018-07-21 10:00:00 CEST
    uint public constant VREO_SALE_PHASE_1_END_TIME = 1532462400;  // 2018-07-24 22:00:00 CEST
    uint public constant VREO_SALE_PHASE_2_END_TIME = 1533153600;  // 2018-08-01 22:00:00 CEST
    uint public constant VREO_SALE_CLOSING_TIME     = 1534622400;  // 2018-08-18 22:00:00 CEST
    uint public constant KYC_VERIFICATION_END_TIME  = 1535832000;  // 2018-09-01 22:00:00 CEST

    // Amount of ICONIQ token investors need per Wei invested in ICONIQ PreSale.
    uint public constant ICONIQ_TOKENS_NEEDED_PER_INVESTED_WEI = 500;

    // ICONIQ Token
    ERC20Basic public iconiqToken;

    // addresses token shares are minted to in finalization
    address public teamAddress;
    address public advisorsAddress;
    address public legalsAddress;
    address public bountyAddress;

    // Amount of token available for purchase
    uint public remainingTokensForSale;

    /// @dev Log entry on rate changed
    /// @param newRate the new rate
    event RateChanged(uint newRate);

    /// @dev Constructor
    /// @param _token A VreoToken
    /// @param _rate the initial rate.
    /// @param _iconiqToken An IconiqInterface
    /// @param _teamAddress Ethereum address of Team
    /// @param _advisorsAddress Ethereum address of Advisors
    /// @param _legalsAddress Ethereum address of Legals
    /// @param _bountyAddress A VreoTokenBounty
    /// @param _wallet MultiSig wallet address the ETH is forwarded to.
    constructor(
        VreoToken _token,
        uint _rate,
        ERC20Basic _iconiqToken,
        address _teamAddress,
        address _advisorsAddress,
        address _legalsAddress,
        address _bountyAddress,
        address _wallet
    )
        public
        Crowdsale(_rate, _wallet, _token)
        TimedCrowdsale(ICONIQ_SALE_OPENING_TIME, VREO_SALE_CLOSING_TIME)
    {
        // Token sanity check
        require(_token.cap() >= TOTAL_TOKEN_CAP_OF_SALE
                                + TOKEN_SHARE_OF_TEAM
                                + TOKEN_SHARE_OF_ADVISORS
                                + TOKEN_SHARE_OF_LEGALS
                                + TOKEN_SHARE_OF_BOUNTY);

        // Sanity check of addresses
        require(address(_iconiqToken) != address(0)
                && _teamAddress != address(0)
                && _advisorsAddress != address(0)
                && _legalsAddress != address(0)
                && _bountyAddress != address(0));

        iconiqToken = _iconiqToken;
        teamAddress = _teamAddress;
        advisorsAddress = _advisorsAddress;
        legalsAddress = _legalsAddress;
        bountyAddress = _bountyAddress;

        remainingTokensForSale = TOTAL_TOKEN_CAP_OF_SALE;
    }

    /// @dev Distribute presale
    /// @param _investors  list of investor addresses
    /// @param _amounts  list of token amounts purchased by investors
    function distributePresale(address[] _investors, uint[] _amounts) public onlyOwner {
        require(!hasClosed());
        require(_investors.length == _amounts.length);

        uint totalAmount = 0;

        for (uint i = 0; i < _investors.length; ++i) {
            VreoToken(token).mint(_investors[i], _amounts[i]);
            totalAmount = totalAmount.add(_amounts[i]);
        }

        remainingTokensForSale = remainingTokensForSale.sub(totalAmount);
    }

    /// @dev Set rate
    /// @param _newRate the new rate
    function setRate(uint _newRate) public onlyOwner {
        // A rate change by a magnitude order of ten and above is rather a typo than intention.
        // If it was indeed desired, several setRate transactions have to be sent.
        require(rate / 10 < _newRate && _newRate < 10 * rate);

        rate = _newRate;

        emit RateChanged(_newRate);
    }

    /// @dev unverified investors can withdraw their money only after the VREO Sale ended
    function withdrawInvestment() public {
        require(hasClosed());

        super.withdrawInvestment();
    }

    /// @dev Is the sale for ICONIQ investors ongoing?
    /// @return bool
    function iconiqSaleOngoing() public view returns (bool) {
        return ICONIQ_SALE_OPENING_TIME <= now && now <= ICONIQ_SALE_CLOSING_TIME;
    }

    /// @dev Is the Vreo main sale ongoing?
    /// @return bool
    function vreoSaleOngoing() public view returns (bool) {
        return VREO_SALE_OPENING_TIME <= now && now <= VREO_SALE_CLOSING_TIME;
    }

    /// @dev Get maximum possible wei investment while Iconiq sale
    /// @param _investor an investors Ethereum address
    /// @return Maximum allowed wei investment
    function getIconiqMaxInvestment(address _investor) public view returns (uint) {
        uint iconiqBalance = iconiqToken.balanceOf(_investor);
        uint prorataLimit = iconiqBalance.div(ICONIQ_TOKENS_NEEDED_PER_INVESTED_WEI);

        // Substract Wei amount already invested.
        return prorataLimit.sub(investments[_investor].totalWeiInvested);
    }

    /// @dev Pre validate purchase
    /// @param _beneficiary an investors Ethereum address
    /// @param _weiAmount wei amount invested
    function _preValidatePurchase(address _beneficiary, uint _weiAmount) internal {
        super._preValidatePurchase(_beneficiary, _weiAmount);

        require(iconiqSaleOngoing() && getIconiqMaxInvestment(msg.sender) >= _weiAmount || vreoSaleOngoing());
    }

    /// @dev Get token amount
    /// @param _weiAmount wei amount invested
    /// @return token amount with bonus
    function _getTokenAmount(uint _weiAmount) internal view returns (uint) {
        uint tokenAmount = super._getTokenAmount(_weiAmount);

        if (now <= ICONIQ_SALE_CLOSING_TIME) {
            return tokenAmount.mul(100 + BONUS_PCT_IN_ICONIQ_SALE).div(100);
        }

        if (now <= VREO_SALE_PHASE_1_END_TIME) {
            return tokenAmount.mul(100 + BONUS_PCT_IN_VREO_SALE_PHASE_1).div(100);
        }

        if (now <= VREO_SALE_PHASE_2_END_TIME) {
            return tokenAmount.mul(100 + BONUS_PCT_IN_VREO_SALE_PHASE_2).div(100);
        }

        return tokenAmount;  // No bonus
    }

    /// @dev Deliver tokens
    /// @param _beneficiary an investors Ethereum address
    /// @param _tokenAmount token amount to deliver
    function _deliverTokens(address _beneficiary, uint _tokenAmount) internal {
        remainingTokensForSale = remainingTokensForSale.sub(_tokenAmount);

        super._deliverTokens(_beneficiary, _tokenAmount);
    }

    /// @dev Finalization
    function finalization() internal {
        require(now >= KYC_VERIFICATION_END_TIME);

        VreoToken(token).mint(teamAddress, TOKEN_SHARE_OF_TEAM);
        VreoToken(token).mint(advisorsAddress, TOKEN_SHARE_OF_ADVISORS);
        VreoToken(token).mint(legalsAddress, TOKEN_SHARE_OF_LEGALS);
        VreoToken(token).mint(bountyAddress, TOKEN_SHARE_OF_BOUNTY);

        VreoToken(token).finishMinting();
        VreoToken(token).unpause();

        super.finalization();
    }

}

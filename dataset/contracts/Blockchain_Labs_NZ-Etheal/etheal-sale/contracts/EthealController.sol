pragma solidity ^0.4.17;

import "./SafeMath.sol";
import "./ERC20MiniMe.sol";
import "./Crowdsale.sol";
import "./TokenController.sol";
import "./Pausable.sol";
import "./Hodler.sol";
import "./TokenVesting.sol";
import "./HasNoTokens.sol";


/**
 * @title EthealController
 * @author thesved
 * @notice Controller of the Etheal Token
 * @dev Crowdsale can be only replaced when no active crowdsale is running.
 *  The contract is paused by default. It has to be unpaused to enable token transfer.
 */
contract EthealController is Pausable, HasNoTokens, TokenController {
    using SafeMath for uint;

    // when migrating this contains the address of the new controller
    TokenController public newController;

    // token contract
    ERC20MiniMe public ethealToken;

    // distribution of tokens
    uint256 public constant ETHEAL_UNIT = 10**18;
    uint256 public constant THOUSAND = 10**3;
    uint256 public constant MILLION = 10**6;
    uint256 public constant TOKEN_SALE1_PRE = 9 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_SALE1_NORMAL = 20 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_SALE2 = 9 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_SALE3 = 5 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_HODL_3M = 1 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_HODL_6M = 2 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_HODL_9M = 7 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_REFERRAL = 2 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_BOUNTY = 1500 * THOUSAND * ETHEAL_UNIT;
    uint256 public constant TOKEN_COMMUNITY = 20 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_TEAM = 14 * MILLION * ETHEAL_UNIT;
    uint256 public constant TOKEN_FOUNDERS = 6500 * THOUSAND * ETHEAL_UNIT;
    uint256 public constant TOKEN_INVESTORS = 3 * MILLION * ETHEAL_UNIT;

    // addresses only SALE will remain, the others will be real eth addresses
    address public SALE = 0X1;
    address public FOUNDER1 = 0X2;
    address public FOUNDER2 = 0X3;
    address public INVESTOR1 = 0X4;
    address public INVESTOR2 = 0X5;

    // addresses for multisig and crowdsale
    address public ethealMultisigWallet;
    Crowdsale public crowdsale;

    // hodler reward contract
    Hodler public hodlerReward;

    // token grants
    TokenVesting[] public tokenGrants;
    uint256 public constant VESTING_TEAM_CLIFF = 365 days;
    uint256 public constant VESTING_TEAM_DURATION = 4 * 365 days;
    uint256 public constant VESTING_ADVISOR_CLIFF = 3 * 30 days;
    uint256 public constant VESTING_ADVISOR_DURATION = 6 * 30 days;


    /// @dev only the crowdsale can call it
    modifier onlyCrowdsale() {
        require(msg.sender == address(crowdsale));
        _;
    }

    /// @dev only the crowdsale can call it
    modifier onlyEthealMultisig() {
        require(msg.sender == address(ethealMultisigWallet));
        _;
    }


    ////////////////
    // Constructor, overrides
    ////////////////

    /// @notice Constructor for Etheal Controller
    function EthealController(address _wallet) {
        require(_wallet != address(0));

        paused = true;
        ethealMultisigWallet = _wallet;
    }

    /// @dev overrides HasNoTokens#extractTokens to make it possible to extract any tokens after migration or before that any tokens except etheal
    function extractTokens(address _token, address _claimer) onlyOwner public {
        require(newController != address(0) || _token != address(ethealToken));

        super.extractTokens(_token, _claimer);
    }


    ////////////////
    // Manage crowdsale
    ////////////////

    /// @notice Set crowdsale address and transfer HEAL tokens from ethealController's SALE address
    /// @dev Crowdsale can be only set when the current crowdsale is not active and ethealToken is set
    function setCrowdsaleTransfer(address _sale, uint256 _amount) public onlyOwner {
        require (_sale != address(0) && !isCrowdsaleOpen() && address(ethealToken) != address(0));

        crowdsale = Crowdsale(_sale);

        // transfer HEAL tokens to crowdsale account from the account of controller
        require(ethealToken.transferFrom(SALE, _sale, _amount));
    }

    /// @notice Is there a not ended crowdsale?
    /// @return true if there is no crowdsale or the current crowdsale is not yet ended but started
    function isCrowdsaleOpen() public view returns (bool) {
        return address(crowdsale) != address(0) && !crowdsale.hasEnded() && crowdsale.hasStarted();
    }


    ////////////////
    // Manage grants
    ////////////////

    /// @notice Grant vesting token to an address
    function createGrant(address _beneficiary, uint256 _amount, bool _revocable, bool _advisor) public onlyOwner {
        require(_beneficiary != address(0) && _amount > 0);

        // create token grant
        if (_advisor) {
            tokenGrants.push(new TokenVesting(_beneficiary, now, VESTING_ADVISOR_CLIFF, VESTING_ADVISOR_DURATION, _revocable));
        } else {
            tokenGrants.push(new TokenVesting(_beneficiary, now, VESTING_TEAM_CLIFF, VESTING_TEAM_DURATION, _revocable));
        }

        // transfer funds to the grant
        require(ethealToken.transfer(address(tokenGrants[tokenGrants.length.sub(1)]), _amount));
    }

    /// @notice Transfer tokens to a grant until it is starting
    function transferToGrant(uint256 _id, uint256 _amount) public onlyOwner {
        require(_id < tokenGrants.length && _amount > 0 && now < tokenGrants[_id].start());

        // transfer funds to the grant
        require(ethealToken.transfer(address(tokenGrants[_id]), _amount));
    }

    /// @dev Revoking grant
    function revokeGrant(uint256 _id) public onlyOwner {
        require(_id < tokenGrants.length);

        tokenGrants[_id].revoke(ethealToken);
    }

    /// @notice Returns the token grant count
    function getGrantCount() view public returns (uint) {
        return tokenGrants.length;
    }


    ////////////////
    // BURN, handle ownership - only multsig can call these functions!
    ////////////////

    /// @notice contract can burn its own or its sale tokens
    function burn(address _where, uint256 _amount) public onlyEthealMultisig {
        require(_where == address(this) || _where == SALE);

        require(ethealToken.destroyTokens(_where, _amount));
    }

    /// @notice replaces controller when it was not yet replaced, only multisig can do it
    function setNewController(address _controller) public onlyEthealMultisig {
        require(_controller != address(0) && newController == address(0));

        newController = TokenController(_controller);
        ethealToken.changeController(_controller);
        hodlerReward.transferOwnership(_controller);

        // send eth
        uint256 _stake = this.balance;
        if (_stake > 0)
            _controller.transfer(_stake);

        // send tokens
        _stake = ethealToken.balanceOf(this);
        if (_stake > 0)
            ethealToken.transfer(_controller, _stake);
    }

    /// @notice Set new multisig wallet, to make it upgradable.
    function setNewMultisig(address _wallet) public onlyEthealMultisig {
        require(_wallet != address(0));

        ethealMultisigWallet = _wallet;
    }


    ////////////////
    // When PAUSED
    ////////////////

    /// @notice set the token, if no hodler provided then creates a hodler reward contract
    function setEthealToken(address _token, address _hodler) public onlyOwner whenPaused {
        require(_token != address(0));

        ethealToken = ERC20MiniMe(_token);

        
        if (_hodler != address(0)) {
            // set hodler reward contract if provided
            hodlerReward = Hodler(_hodler);
        } else if (hodlerReward == address(0)) {
            // create hodler reward contract if not yet created
            hodlerReward = new Hodler(TOKEN_HODL_3M, TOKEN_HODL_6M, TOKEN_HODL_9M);
        }

        // MINT tokens if not minted yet
        if (ethealToken.totalSupply() == 0) {
            // sale
            ethealToken.generateTokens(SALE, TOKEN_SALE1_PRE.add(TOKEN_SALE1_NORMAL).add(TOKEN_SALE2).add(TOKEN_SALE3));
            // hodler reward
            ethealToken.generateTokens(address(hodlerReward), TOKEN_HODL_3M.add(TOKEN_HODL_6M).add(TOKEN_HODL_9M));
            // bounty + referral
            ethealToken.generateTokens(owner, TOKEN_BOUNTY.add(TOKEN_REFERRAL));
            // community fund
            ethealToken.generateTokens(address(ethealMultisigWallet), TOKEN_COMMUNITY);
            // team -> grantable
            ethealToken.generateTokens(address(this), TOKEN_FOUNDERS.add(TOKEN_TEAM));
            // investors
            ethealToken.generateTokens(INVESTOR1, TOKEN_INVESTORS.div(3).mul(2));
            ethealToken.generateTokens(INVESTOR2, TOKEN_INVESTORS.div(3));
        }
    }


    ////////////////
    // Proxy for Hodler contract
    ////////////////
    
    /// @notice Proxy call for setting hodler start time
    function setHodlerTime(uint256 _time) public onlyCrowdsale {
        hodlerReward.setHodlerTime(_time);
    }

    /// @notice Proxy call for adding hodler stake
    function addHodlerStake(address _beneficiary, uint256 _stake) public onlyCrowdsale {
        hodlerReward.addHodlerStake(_beneficiary, _stake);
    }

    /// @notice Proxy call for setting hodler stake
    function setHodlerStake(address _beneficiary, uint256 _stake) public onlyCrowdsale {
        hodlerReward.setHodlerStake(_beneficiary, _stake);
    }


    ////////////////
    // MiniMe Controller functions
    ////////////////

    /// @notice No eth payment to the token contract
    function proxyPayment(address _owner) payable public returns (bool) {
        revert();
    }

    /// @notice Before transfers are enabled for everyone, only this and the crowdsale contract is allowed to distribute HEAL
    function onTransfer(address _from, address _to, uint256 _amount) public returns (bool) {
        // moving any funds makes hodl participation invalid
        hodlerReward.invalidate(_from);

        return !paused || _from == address(this) || _to == address(this) || _from == address(crowdsale) || _to == address(crowdsale);
    }

    function onApprove(address _owner, address _spender, uint256 _amount) public returns (bool) {
        return !paused;
    }

    /// @notice Retrieve mistakenly sent tokens (other than the etheal token) from the token contract 
    function claimTokenTokens(address _token) public onlyOwner {
        require(_token != address(ethealToken));

        ethealToken.claimTokens(_token);
    }
}
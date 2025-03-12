//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "./BrnMetaverse.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

/**
 * @title TokenPresale
 * TokenPresale allows investors to make
 * token purchases and assigns them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */

contract Presale is Pausable, Ownable {
    /**
     * crowdsale constructor
     * @param _wallet who receives invested ether
     * @param _cap above which the crowdsale is closed
     */

    constructor(
        address _priceFeedAddress,
        address _tokenAddress,
        address payable _wallet,
        uint256 _cap // 50,000,000 BRN
    ) {
        require(_wallet != address(0));
        require(_tokenAddress != address(0));
        require(_priceFeedAddress != address(0));
        require(_cap > 0);
        TokenAddress = _tokenAddress;
        priceFeedAddress = _priceFeedAddress;

        wallet = _wallet;
        cap = _cap * (10**18); //cap in tokens base units (=1000000 tokens)
        phase1Cap = (cap * 14) / 100;
        phase2Cap = (cap * 36) / 100;
        phase3Cap = (cap * 50) / 100;
    }

    mapping(address => uint256) public phase1Balance;
    mapping(address => uint256) public phase2Balance;
    mapping(address => uint256) public phase3Balance;

    mapping(address => uint256) public phase1USDAmount;
    mapping(address => uint256) public phase2USDAmount;
    mapping(address => uint256) public phase3USDAmount;

    mapping(address => uint256) public Contribution;

    address priceFeedAddress;

    uint256 public phase1Start = 0;
    uint256 public phase1End = 0;
    uint256 public phase1LockPeriod = 24 weeks;
    uint256 public phase2Start = 0;
    uint256 public phase2End = 0;
    uint256 public phase2LockPeriod = 16 weeks;
    uint256 public phase3Start = 0;
    uint256 public phase3End = 0;
    uint256 public phase3LockPeriod = 8 weeks;

    // The token being sold
    address immutable TokenAddress;

    // address where funds are collected
    address public wallet;

    //amount of wei raised 
    uint256 public weiRaised; 

    // amount of tokens sold in each phase
    uint256 public tokenSoldPhase1;
    uint256 public tokenSoldPhase2;
    uint256 public tokenSoldPhase3;

    uint256 public totalTokensOwnedByInvestors;

    // cap above which the crowdsale is ended
    uint256 public cap;
    uint256 public phase1Cap;
    uint256 public phase2Cap;
    uint256 public phase3Cap;

    string public contactInformation;

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(
        address indexed purchaser,
        address indexed beneficiary,
        uint256 value,
        uint256 amount
    );

    event TokenWithdrawal(address indexed beneficiary, uint256 amount);

    function startNextPhase() external onlyOwner {
        if (phase1Start == phase2Start && phase3Start == phase2Start) {
            phase1Start = block.timestamp;
            phase1End = phase1Start + 15 days;
            phase2Start = phase1End;
            phase2End = phase2Start + 15 days;
            phase3Start = phase2End;
            phase3End = phase3Start + 15 days;
        } else if (
            block.timestamp > phase1Start && block.timestamp < phase2Start
        ) {
            require(
                tokenSoldPhase1 == phase1Cap,
                "Phase 1 cap has not been exhausted"
            );
            phase1End = block.timestamp;
            phase2Start = phase1End;
            phase2End = phase2Start + 15 days;
            phase3Start = phase2End;
            phase3End = phase3Start + 15 days;
        } else if (
            block.timestamp > phase2Start && block.timestamp < phase3Start
        ) {
            require(
                tokenSoldPhase2 == phase2Cap,
                "Phase 2 cap has not been exhausted"
            );
            phase2End = block.timestamp;
            phase3Start = phase2End;
            phase3End = phase3Start + 15 days;
        } else if (
            block.timestamp > phase3Start && block.timestamp < phase3End
        ) {
            require(
                tokenSoldPhase3 == phase3Cap,
                "Phase 2 cap has not been exhausted"
            );
            phase3End = block.timestamp;
        }
    }

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen() {
        // solium-disable-next-line security/no-block-members
        require(block.timestamp >= phase1Start && block.timestamp <= phase3End);
        _;
    }

    /**
     * @dev Checks whether the period in which the crowdsale is open has already elapsed.
     * @return Whether crowdsale period has elapsed
     */
    function phase1HasClosed() public view returns (bool) {
        return block.timestamp > phase2Start;
    }

    function phase2HasClosed() public view returns (bool) {
        return block.timestamp > phase2Start;
    }

    function presaleHasClosed() public view returns (bool) {
        return block.timestamp > phase3End;
    }

    /**
     * @dev Checks whether the period for withdrawal has reach.
     * @return whether the period for withdrawal has reach
     */
    function phase1WithdrawalReach() public view returns (bool) {
        return block.timestamp > phase1Start + phase1LockPeriod;
    }

    function phase2WithdrawalReach() public view returns (bool) {
        return block.timestamp > phase2Start + phase2LockPeriod;
    }

    function phase3WithdrawalReach() public view returns (bool) {
        return block.timestamp > phase3Start + phase3LockPeriod;
    }

    function getPrice() public view returns (uint256, uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    function coinToUSD(uint256 _amountIn) public view returns (uint256) {
        (uint256 inputTokenPrice, uint256 inputTokenDecimals) = getPrice();
        uint256 value2USD = (_amountIn * inputTokenPrice) /
            10**inputTokenDecimals;
        return value2USD;
    }

    // fallback function to buy tokens
    receive() external payable {
        buyTokens(msg.sender);
    }

    function getPhaseArg()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 phaseCap;
        uint256 tokensSold;
        uint256 pricePerToken;
        if (block.timestamp > phase1Start && block.timestamp < phase2Start) {
            phaseCap = phase1Cap;
            tokensSold = tokenSoldPhase1;
            pricePerToken = 10 * 10**18;
        }
        if (block.timestamp > phase2Start && block.timestamp < phase3Start) {
            phaseCap = phase2Cap;
            tokensSold = tokenSoldPhase2;
            pricePerToken = 20 * 10**18;
        }
        if (block.timestamp > phase3Start && block.timestamp < phase3End) {
            phaseCap = phase3Cap;
            tokensSold = tokenSoldPhase3;
            pricePerToken = 30 * 10**18;
        }
        return (phaseCap, tokensSold, pricePerToken);
    }

    /**
     * Low level token purchse function
     * @param beneficiary will recieve the tokens.
     */
    function buyTokens(address beneficiary)
        public
        payable
        whenNotPaused
        onlyWhileOpen
    {
        require(!presaleHasClosed(), "The presale is over");
        require(beneficiary != address(0), "Zero Address");
        require(msg.value > 0, "Empty value");

        uint256 amount = coinToUSD(msg.value);

        uint256 phaseUSDAmount;

        if (block.timestamp > phase1Start && block.timestamp < phase2Start) {
            phaseUSDAmount = phase1USDAmount[beneficiary];
        }
        if (block.timestamp > phase2Start && block.timestamp < phase3Start) {
            phaseUSDAmount = phase2USDAmount[beneficiary];
        }
        if (block.timestamp > phase3Start && block.timestamp < phase3End) {
            phaseUSDAmount = phase3USDAmount[beneficiary];
        }

        require(amount >= 10 * 10**18, "The enter amount is below minimum");
        require(amount <= 10000 * 10**18, "The enter amount is above maximum");
        require(
            amount + phaseUSDAmount <= 10000 * 10**18,
            "Your total purchase will be above the allowable maximum per wallet!"
        );

        (
            uint256 phaseCap,
            uint256 tokensSold,
            uint256 pricePerToken
        ) = getPhaseArg();

        uint256 tokenAmount = (amount * 100 * 10**18) / pricePerToken;
        require(tokenAmount + tokensSold <= phaseCap, "Greater than phase cap");

        if (block.timestamp > phase1Start && block.timestamp < phase2Start) {
            phase1USDAmount[beneficiary] += amount;
            phase1Balance[beneficiary] += tokenAmount;
            tokenSoldPhase1 += tokenAmount;
        }
        if (block.timestamp > phase2Start && block.timestamp < phase3Start) {
            phase2USDAmount[beneficiary] += amount;
            phase2Balance[beneficiary] += tokenAmount;
            tokenSoldPhase2 += tokenAmount;
        }
        if (block.timestamp > phase3Start && block.timestamp < phase3End) {
            phase3USDAmount[beneficiary] += amount;
            phase3Balance[beneficiary] += tokenAmount;
            tokenSoldPhase3 += tokenAmount;
        }
        Contribution[beneficiary] += msg.value;
        totalTokensOwnedByInvestors += tokenAmount;

        uint256 weiAmount = msg.value;
        // update weiRaised
        weiRaised = weiRaised + weiAmount;

        emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokenAmount);
        forwardFunds();
    }

    function withdrawRemainingTokens() external onlyOwner {
        require(block.timestamp > phase3End);
        uint256 presaleTokenBalance = IERC20(TokenAddress).balanceOf(
            address(this)
        );
        uint256 withdrawableBalance = presaleTokenBalance -
            totalTokensOwnedByInvestors;
        IERC20(TokenAddress).transfer(msg.sender, withdrawableBalance);
    }

    // withdraw ERC20 Tokens
    function withdrawToken() public whenNotPaused {
        require(
            phase1WithdrawalReach() ||
                phase2WithdrawalReach() ||
                phase3WithdrawalReach(),
            "No phase withdrawal has reached yet!"
        );
        uint256 balance;
        if (phase1WithdrawalReach()) {
            balance =
                phase1Balance[msg.sender] +
                phase2Balance[msg.sender] +
                phase3Balance[msg.sender];
            phase1Balance[msg.sender] = 0;
            phase2Balance[msg.sender] = 0;
            phase3Balance[msg.sender] = 0;
        } else if (phase2WithdrawalReach()) {
            balance = phase3Balance[msg.sender] + phase2Balance[msg.sender];
            phase3Balance[msg.sender] = 0;
            phase2Balance[msg.sender] = 0;
        } else if (phase3WithdrawalReach()) {
            balance = phase3Balance[msg.sender];
            phase3Balance[msg.sender] = 0;
        }

        totalTokensOwnedByInvestors -= balance;

        IERC20(TokenAddress).transfer(msg.sender, balance);
        emit TokenWithdrawal(msg.sender, balance);
    }

    // send ether to the fund collection wallet
    function forwardFunds() internal {
        payable(wallet).transfer(msg.value);
    }

    function setContactInformation(string memory info) public onlyOwner {
        contactInformation = info;
    }
}
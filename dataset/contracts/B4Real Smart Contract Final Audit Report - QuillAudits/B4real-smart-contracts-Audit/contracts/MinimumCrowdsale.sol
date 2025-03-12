// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./library/TransferHelper.sol";
import "./IERC20.sol";
import "./library/Ownable.sol";
import "./Metadata.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MinimalCrowdsale is ReentrancyGuard, Ownable, Metadata {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint8;

    ///@notice TokenAddress available for purchase in this Crowdsale
    IERC20 public token;

    mapping(address => bool) public validInputToken;

    //@notice the amount of token investor will recieve against 1 inputToken
    mapping(address => uint256) public inputTokenRate;

    IERC20[] private inputToken;

    /// @notice end of crowdsale as a timestamp
    uint256 public crowdsaleEndTime;

    /// @notice Number of Tokens Allocated for crowdsale
    uint256 public crowdsaleTokenAllocated;

    uint256 public maxUserAllocation;

    /// @notice amount vested for a investor.
    mapping(address => uint256) public vestedAmount;

    bool public initialized;

    /**
     * Event for Tokens purchase logging
     * @param investor who invested & got the tokens
     * @param investedAmount of inputToken paid for purchase
     * @param tokenPurchased amount
     * @param inputToken address used to invest
     * @param tokenRemaining amount of token still remaining for sale in crowdsale
     */
    event TokenPurchase(
        address indexed investor,
        uint256 investedAmount,
        uint256 indexed tokenPurchased,
        IERC20 indexed inputToken,
        uint256 tokenRemaining
    );

    /// @notice event emitted when a successful drawn down of vesting tokens is made
    event DrawDown(
        address indexed _investor,
        uint256 _amount,
        uint256 indexed drawnTime
    );

    /// @notice event emitted when crowdsale is ended manually
    event CrowdsaleEndedManually(uint256 indexed crowdsaleEndedManuallyAt);

    /// @notice event emitted when the crowdsale raised funds are withdrawn by the owner
    event FundsWithdrawn(
        address indexed beneficiary,
        IERC20 indexed _token,
        uint256 amount
    );

    /// @notice event emitted when the owner updates max token allocation per user
    event MaxAllocationUpdated(uint256 indexed newAllocation);

    event URLUpdated(address _tokenAddress, string _tokenUrl);

    event TokenRateUpdated(address inputToken, uint256 rate);

    event CrowdsaleTokensAllocationUpdated(
        uint256 indexed crowdsaleTokenAllocated
    );

    modifier isCrowdsaleActive() {
        require(
            _getNow() <= crowdsaleEndTime || crowdsaleEndTime == 0,
            "Crowdsale is not active"
        );
        _;
    }

    /**
     * @notice Initializes the Crowdsale contract. This is called only once upon Crowdsale creation.
     */
    function init(bytes memory _encodedData) external {
        require(initialized == false, "Contract already initialized");
        IERC20[] memory inputTokens;
        uint256[] memory _rate;
        string memory tokenURL;
        (
            token,
            crowdsaleTokenAllocated,
            inputTokens,
            _rate,
            crowdsaleEndTime
        ) = abi.decode(
            _encodedData,
            (IERC20, uint256, IERC20[], uint256[], uint256)
        );

        (, , , , , owner, tokenURL, maxUserAllocation) = abi.decode(
            _encodedData,
            (
                IERC20,
                uint256,
                IERC20[],
                uint256[],
                uint256,
                address,
                string,
                uint256
            )
        );

        TransferHelper.safeTransferFrom(
            address(token),
            msg.sender,
            address(this),
            crowdsaleTokenAllocated
        );

        updateMeta(address(token), address(0), tokenURL);
        for (uint256 i = 0; i < inputTokens.length; i++) {
            inputToken.push(inputTokens[i]);
            validInputToken[address(inputTokens[i])] = true;
            inputTokenRate[address(inputTokens[i])] = _rate[i];
            updateMeta(address(inputTokens[i]), address(0), "");
        }

        initialized = true;
    }

    function purchaseToken(IERC20 _inputToken, uint256 _inputTokenAmount)
        external
        nonReentrant
        isCrowdsaleActive
    {
        require(
            validInputToken[address(_inputToken)],
            "Unsupported Input token"
        );

        uint8 inputTokenDecimals = _inputToken.decimals();
        uint256 tokenPurchased = inputTokenDecimals >= 18
            ? _inputTokenAmount.mul(inputTokenRate[address(_inputToken)]).div(
                10**(inputTokenDecimals - 18)
            )
            : _inputTokenAmount.mul(inputTokenRate[address(_inputToken)]).mul(
                10**(18 - inputTokenDecimals)
            );

        uint8 tokenDecimal = token.decimals();
        tokenPurchased = tokenDecimal >= 36
            ? tokenPurchased.mul(10**(tokenDecimal - 36))
            : tokenPurchased.div(10**(36 - tokenDecimal));

        if (maxUserAllocation != 0)
            require(
                vestedAmount[msg.sender].add(tokenPurchased) <=
                    maxUserAllocation,
                "User Exceeds personal hardcap"
            );

        require(
            tokenPurchased <= crowdsaleTokenAllocated,
            "Exceeding purchase amount"
        );

        TransferHelper.safeTransferFrom(
            address(_inputToken),
            msg.sender,
            address(this),
            _inputTokenAmount
        );

        crowdsaleTokenAllocated = crowdsaleTokenAllocated.sub(tokenPurchased);
        _updateVestingSchedule(msg.sender, tokenPurchased);

        // _drawDown(msg.sender);

        TransferHelper.safeTransfer(address(token), msg.sender, tokenPurchased);

        emit TokenPurchase(
            msg.sender,
            _inputTokenAmount,
            tokenPurchased,
            _inputToken,
            crowdsaleTokenAllocated
        );
    }

    function updateTokenURL(address _tokenAddress, string memory _url)
        external
        onlyOwner
    {
        updateMetaURL(_tokenAddress, _url);
        emit URLUpdated(_tokenAddress, _url);
    }

    function updateInputTokenRate(address _inputToken, uint256 _rate)
        external
        onlyOwner
    {
        inputTokenRate[_inputToken] = _rate;

        validInputToken[_inputToken] = true;

        emit TokenRateUpdated(_inputToken, _rate);
    }

    /**
     * @dev Update the token allocation a user can purchase
     * Can only be called by the current owner.
     */
    function updateMaxUserAllocation(uint256 _maxUserAllocation)
        external
        onlyOwner
    {
        maxUserAllocation = _maxUserAllocation;
        emit MaxAllocationUpdated(_maxUserAllocation);
    }

    /**
     * @dev Update max tokens allocated to crowdsale
     * Can only be called by the current owner.
     */
    function updateMaxCrowdsaleAllocation(uint256 _crowdsaleTokenAllocated)
        external
        onlyOwner
    {
        crowdsaleTokenAllocated = _crowdsaleTokenAllocated;
        emit CrowdsaleTokensAllocationUpdated(crowdsaleTokenAllocated);
    }

    function endCrowdsale() external onlyOwner {
        crowdsaleEndTime = _getNow();

        if (crowdsaleTokenAllocated != 0) {
            withdrawFunds(token, crowdsaleTokenAllocated); //when crowdsaleEnds withdraw unsold tokens to the owner
        }
        emit CrowdsaleEndedManually(crowdsaleEndTime);
    }

    /**
     * @notice Vesting schedule and associated data for an investor
     * @return _amount
     */
    function vestingScheduleForBeneficiary(address _investor)
        external
        view
        returns (uint256 _amount)
    {
        return (vestedAmount[_investor]);
    }

    function getValidInputTokens() external view returns (IERC20[] memory) {
        return inputToken;
    }

    function withdrawFunds(IERC20 _token, uint256 amount) public onlyOwner {
        require(
            getContractTokenBalance(_token) >= amount,
            "the contract doesnt have tokens"
        );

        TransferHelper.safeTransfer(address(_token), msg.sender, amount);

        emit FundsWithdrawn(msg.sender, _token, amount);
    }

    function getContractTokenBalance(IERC20 _token)
        public
        view
        returns (uint256)
    {
        return _token.balanceOf(address(this));
    }

    function _updateVestingSchedule(address _investor, uint256 _amount)
        internal
    {
        require(_investor != address(0), "Beneficiary cannot be empty");
        require(_amount > 0, "Amount cannot be empty");

        vestedAmount[_investor] = vestedAmount[_investor].add(_amount);
    }

    function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }
}

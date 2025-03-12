pragma solidity ^0.4.24;


import "./Whitelist.sol";
import "./RewardToken.sol";


/// @title TRVLToken smart contract
contract TRVLToken is RewardToken {
    string public constant name = "TRVL Token";
    string public constant symbol = "TRVL";
    uint8 public constant decimals = 18;
    uint256 public constant TOTAL_CAP = 600000000 * (10 ** uint256(decimals));

    event TransferReward(address from, address to, uint256 value);

    /// @dev Verifies the user has enough tokens to cover the payment.
    modifier senderHasEnoughTokens(uint256 _regularTokens, uint256 _rewardTokens) {
        require(rewardBalances[msg.sender] >= _rewardTokens, "User does not have enough reward tokens!");
        require(balances[msg.sender] >= _regularTokens, "User does not have enough regular tokens!");
        _;
    }

    /// @dev Verifies the amount is > 0.
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "The amount specified is 0!");
        _;
    }

    /// @dev The TRVL Token is an ERC20 complaint token with a built in reward system that
    /// gives users back a percentage of tokens spent on travel. These tokens are
    /// non-transferable and can only be spent on travel through the TravelBlock website.
    /// The percentages are defined in the rewardPercentage array and can be modified by
    /// the TravelBlock team. The token is created with the entire balance being owned by the address that deploys.
    constructor() RewardToken(decimals) public {
        totalSupply_ = TOTAL_CAP;
        balances[owner] = totalSupply_;
        emit Transfer(0x0, owner, totalSupply_);
    }

    /// @notice Process a payment that prioritizes the use of regular tokens.
    /// @dev Uses up all of the available regular tokens, before using rewards tokens to cover a payment. Pushes the calculated amounts
    /// into their respective function calls.
    /// @param _amount The total tokens to be paid.
    function paymentRegularTokensPriority (uint256 _amount, uint256 _rewardPercentageIndex) public {
        uint256 regularTokensAvailable = balances[msg.sender];

        if (regularTokensAvailable >= _amount) {
            paymentRegularTokens(_amount, _rewardPercentageIndex);

        } else {
            if (regularTokensAvailable > 0) {
                uint256 amountOfRewardsTokens = _amount.sub(regularTokensAvailable);
                paymentMixed(regularTokensAvailable, amountOfRewardsTokens, _rewardPercentageIndex);
            } else {
                paymentRewardTokens(_amount);
            }
        }
    }

    /// @notice Process a payment that prioritizes the use of reward tokens.
    /// @dev Uses up all of the available reward tokens, before using regular tokens to cover a payment. Pushes the calculated amounts
    /// into their respective function calls.
    /// @param _amount The total tokens to be paid.
    function paymentRewardTokensPriority (uint256 _amount, uint256 _rewardPercentageIndex) public {
        uint256 rewardTokensAvailable = rewardBalances[msg.sender];

        if (rewardTokensAvailable >= _amount) {
            paymentRewardTokens(_amount);
        } else {
            if (rewardTokensAvailable > 0) {
                uint256 amountOfRegularTokens = _amount.sub(rewardTokensAvailable);
                paymentMixed(amountOfRegularTokens, rewardTokensAvailable, _rewardPercentageIndex);
            } else {
                paymentRegularTokens(_amount, _rewardPercentageIndex);
            }
        }
    }

    /// @notice Process a TRVL tokens payment with a combination of regular and rewards tokens.
    /// @dev calls the regular/rewards payment methods respectively.
    /// @param _regularTokenAmount The amount of regular tokens to be processed.
    /// @param _rewardTokenAmount The amount of reward tokens to be processed.
    function paymentMixed (uint256 _regularTokenAmount, uint256 _rewardTokenAmount, uint256 _rewardPercentageIndex) public {
        paymentRewardTokens(_rewardTokenAmount);
        paymentRegularTokens(_regularTokenAmount, _rewardPercentageIndex);
    }

    /// @notice Process a payment using only regular TRVL Tokens with a specified reward percentage.
    /// @dev Adjusts the balances accordingly and applies a reward token bonus. The accounts must be whitelisted because the travel team must own the address
    /// to make transfers on their behalf.
    /// Requires:
    ///     - The contract is not paused
    ///     - The amount being processed is greater than 0
    ///     - The reward index being passed is valid
    ///     - The sender has enough tokens to cover the payment
    ///     - The sender is a whitelisted address
    /// @param _regularTokenAmount The amount of regular tokens being used for the payment.
    /// @param _rewardPercentageIndex The index pointing to the percentage of reward tokens to be applied.
    function paymentRegularTokens (uint256 _regularTokenAmount, uint256 _rewardPercentageIndex)
        public
        validAmount(_regularTokenAmount)
        isValidRewardIndex(_rewardPercentageIndex)
        senderHasEnoughTokens(_regularTokenAmount, 0)
        isWhitelisted(msg.sender)
        whenNotPaused
    {
        // 1. Pay the specified amount with from the balance of the user/sender.
        balances[msg.sender] = balances[msg.sender].sub(_regularTokenAmount);

        // 2. distribute reward tokens to the user.
        uint256 rewardAmount = getRewardTokenPercentage(_regularTokenAmount, _rewardPercentageIndex);
        rewardBalances[msg.sender] = rewardBalances[msg.sender].add(rewardAmount);
        emit TransferReward(owner, msg.sender, rewardAmount);

        // 3. Update the owner balance minus the reward tokens.
        balances[owner] = balances[owner].add(_regularTokenAmount.sub(rewardAmount));
        emit Transfer(msg.sender, owner, _regularTokenAmount.sub(rewardAmount));
    }

    /// @notice Process a payment using only reward TRVL Tokens.
    /// @dev Adjusts internal balances accordingly. The accounts must be whitelisted because the travel team must own the address
    /// to make transfers on their behalf.
    /// Requires:
    ///     - The contract is not paused
    ///     - The amount being processed is greater than 0
    ///     - The sender has enough tokens to cover the payment
    ///     - The sender is a whitelisted address
    /// @param _rewardTokenAmount The amount of reward tokens being used for the payment.
    function paymentRewardTokens (uint256 _rewardTokenAmount)
        public
        validAmount(_rewardTokenAmount)
        senderHasEnoughTokens(0, _rewardTokenAmount)
        isWhitelisted(msg.sender)
        whenNotPaused
    {
        rewardBalances[msg.sender] = rewardBalances[msg.sender].sub(_rewardTokenAmount);
        rewardBalances[owner] = rewardBalances[owner].add(_rewardTokenAmount);

        emit TransferReward(msg.sender, owner, _rewardTokenAmount);
    }

    /// @notice Convert a specific amount of regular TRVL tokens from the owner, into reward tokens for a user.
    /// @dev Converts the regular tokens into reward tokens at a 1-1 ratio.
    /// Requires:
    ///     - Owner has enough tokens to convert
    ///     - The specified user is whitelisted
    ///     - The amount being converted is greater than 0
    /// @param _user The user receiving the converted tokens.
    /// @param _amount The amount of tokens to be converted.
    function convertRegularToRewardTokens(address _user, uint256 _amount)
        external
        onlyOwner
        validAmount(_amount)
        senderHasEnoughTokens(_amount, 0)
        isWhitelisted(_user)
    {
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        rewardBalances[_user] = rewardBalances[_user].add(_amount);

        emit TransferReward(msg.sender, _user, _amount);
    }
}

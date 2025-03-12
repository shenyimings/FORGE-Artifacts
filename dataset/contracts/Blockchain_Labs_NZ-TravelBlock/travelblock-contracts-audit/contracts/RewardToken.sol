pragma solidity ^0.4.24;


import "./Whitelist.sol";

/// Standard ERC20 token with the ability to freeze and unfreeze token transfer.
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

/// Blocks ERC223 tokens and allows the smart contract to transfer ownership of
/// ERC20 tokens that are sent to the contract address.
import "openzeppelin-solidity/contracts/ownership/HasNoTokens.sol";


/// @title Reward Token contract that contains all reward token configurations.
contract RewardToken is PausableToken, Whitelist, HasNoTokens{
    /// @dev Any token balances added here must be removed from the balances map.
    mapping(address => uint256) public rewardBalances;

    uint256[] public rewardPercentage;
    uint256 public rewardPercentageDecimals;
    uint256 public rewardPercentageDivisor;

    event RewardPercentage(uint256 index, uint256 percentage);

    /// @dev Verifies the reward index is valid.
    modifier isValidRewardIndex(uint256 _index) {
        require(_index < rewardPercentage.length, "The reward percentage index does not exist!");
        _;
    }

    /// @dev Verifies the reward percentage is valid.
    modifier isValidRewardPercentage(uint256 _percentage) {
        require(_percentage <= rewardPercentageDivisor, "Cannot have a reward percentage greater than 100%!");
        _;
    }

    constructor(uint256 _rewardPercentageDecimals) public {
        rewardPercentageDecimals = _rewardPercentageDecimals;
        rewardPercentageDivisor = (10 ** uint256(_rewardPercentageDecimals)).mul(100);
    }

    /// @notice Adds a reward percentage to the list of available reward percentages, specific to 18 decimals.
    /// @dev To achieve an affective 5% bonus, the sender needs to use 5 x 10^18.
    /// Requires:
    ///     - Msg.sender is an admin
    ///     - Percentage is <= 100%
    /// @param _percentage The new percentage specific to 18 decimals.
    /// @return The index of the percentage added in the rewardPercentage array.
    function addRewardPercentage(uint256 _percentage) public onlyAdmin isValidRewardPercentage(_percentage) returns (uint256 _index) {
        _index = rewardPercentage.length;
        rewardPercentage.push(_percentage);

        emit RewardPercentage(_index, _percentage);
    }

    /// @notice Edits the contents of the percentage array, with the specified parameters.
    /// @dev Allows the owner to edit percentage array contents for a given index.
    /// Requires:
    ///     - Msg.sender is an admin
    ///     - The index must be within the bounds of the rewardPercentage array
    ///     - The new percentage must be <= 100%
    /// @param _index The index of the percentage to be edited.
    /// @param _percentage The new percentage to be used for the given index.
    function updateRewardPercentageByIndex(uint256 _index, uint256 _percentage)
        public
        onlyAdmin
        isValidRewardIndex(_index)
        isValidRewardPercentage(_percentage)
    {
        rewardPercentage[_index] = _percentage;

        emit RewardPercentage(_index, _percentage);
    }

    /// @dev Calculates the reward based on the reward percentage index.
    /// Requires:
    ///     - The index must be within the bounds of the rewardPercentage array
    /// @param _amount The amount tokens to be converted to rewards.
    /// @param _rewardPercentageIndex The location of reward percentage to be applied.
    /// @return The amount of tokens converted to reward tokens.
    function getRewardTokenPercentage(uint256 _amount, uint256 _rewardPercentageIndex)
        internal
        view
        isValidRewardIndex(_rewardPercentageIndex)
        returns(uint256 _rewardPercentage)
    {
        _rewardPercentage = _amount.mul(rewardPercentage[_rewardPercentageIndex]).div(rewardPercentageDivisor);
    }
}

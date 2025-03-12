// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVault.sol";

/**
 * @title Teller Contract
 */
contract Teller is Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @notice Event emitted only on construction.
    event TellerDeployed();

    /// @notice Event emitted when teller toggled.
    event TellerToggled(address teller, bool status);

    /// @notice Event emitted when new commitment added.
    event NewCommitmentAdded(
        uint256 bonus,
        uint256 time,
        uint256 penalty,
        uint256 deciAdjustment
    );

    /// @notice Event emitted when commitment toggled.
    event CommitmentToggled(uint256 index, bool status);

    /// @notice Event emitted when owner set the dev address to get the break commitment fees.
    event PurposeSet(address devAddress);

    /// @notice Event emitted when provider deposit the lp tokens.
    event LpDeposited(address provider, uint256 amount);

    /// @notice Event emitted when provider withdrew the lp tokens.
    event Withdrew(address provider, uint256 amount);

    /// @notice Event emitted when provider commit the lp tokens.
    event Commited(address provider, uint256 commitedAmount);

    /// @notice Event emitted when provider break the commitment.
    event CommitmentBroke(address provider, uint256 tokenSentAmount);

    /// @notice Event emitted when provider claimed.
    event Claimed(address provider, bool success);

    IVault Vault;
    IERC20 LpToken;

    struct Provider {
        uint256 LPDepositedRatio;
        uint256 userWeight;
        uint256 lastClaimedTime;
        uint256 commitmentIndex;
        uint256 committedAmount;
        uint256 commitmentEndTime;
    }

    struct Commitment {
        uint256 bonus;
        uint256 duration;
        uint256 penalty;
        uint256 deciAdjustment;
        bool isActive;
    }

    uint256 totalLP;
    uint256 totalWeight;
    uint256 tellerClosedTime;

    mapping(address => Provider) providerInfo;

    bool tellerOpen;
    address devAddress;
    bool purpose;

    Commitment[] commitmentInfo;

    modifier isTellerOpen() {
        require(tellerOpen, "Teller: Teller is not opened.");
        _;
    }

    modifier isProvider() {
        require(
            providerInfo[msg.sender].LPDepositedRatio != 0,
            "Teller: Caller is not the provider."
        );
        _;
    }
    modifier isTellerClosed() {
        require(!tellerOpen, "Teller: Teller is still active.");
        _;
    }

    /**
     * @dev Constructor function
     * @param _LpToken Interface of LP token
     * @param _Vault Interface of Vault
     */
    constructor(IERC20 _LpToken, IVault _Vault) {
        LpToken = _LpToken;
        Vault = _Vault;
        commitmentInfo.push();

        emit TellerDeployed();
    }

    /**
     * @dev External function to toggle the teller. This function can be called by only owner.
     */
    function toggleTeller() external onlyOwner {
        if (!(tellerOpen = !tellerOpen)) {
            tellerClosedTime = block.timestamp;
        }

        emit TellerToggled(address(this), tellerOpen);
    }

    /**
     * @dev External function to add the commitment. This function can be called by only owner.
     * @param _bonus Amount of bonus
     * @param _days Days of duration
     * @param _penalty Number of penalty
     * @param _deciAdjustment Decimal percentage
     */
    function addCommitment(
        uint256 _bonus,
        uint256 _days,
        uint256 _penalty,
        uint256 _deciAdjustment
    ) external onlyOwner {
        Commitment memory holder;

        holder.bonus = _bonus;
        holder.duration = _days * 1 days;
        holder.penalty = _penalty;
        holder.deciAdjustment = _deciAdjustment;
        holder.isActive = true;

        commitmentInfo.push(holder);

        emit NewCommitmentAdded(_bonus, _days, _penalty, _deciAdjustment);
    }

    /**
     * @dev External function to toggle the commitment. This function can be called by only owner.
     * @param _index Commitment index
     */
    function toggleCommitment(uint256 _index) external onlyOwner {
        require(
            0 < _index && _index < commitmentInfo.length,
            "Teller: Current index is not listed in the commitment array."
        );

        commitmentInfo[_index].isActive = !commitmentInfo[_index].isActive;

        emit CommitmentToggled(_index, commitmentInfo[_index].isActive);
    }

    /**
     * @dev External function to set the dev address to give that address the break commitment fees. This function can be called by only owner.
     * @param _address Dev address
     */
    function setPurpose(address _address) external onlyOwner {
        purpose = true;
        devAddress = _address;

        emit PurposeSet(devAddress);
    }

    /**
     * @dev External function to deposit lp token from providers. Teller must be open.
     * @param _amount LP token amount
     */
    function depositLP(uint256 _amount) external isTellerOpen {
        uint256 contractBalance = LpToken.balanceOf(address(this));
        LpToken.safeTransferFrom(msg.sender, address(this), _amount);

        Provider storage user = providerInfo[msg.sender];
        if (user.LPDepositedRatio != 0) {
            claim();
        } else {
            user.lastClaimedTime = block.timestamp;
        }
        if (contractBalance == totalLP) {
            user.LPDepositedRatio += _amount;
            totalLP += _amount;
        } else {
            uint256 _adjustedAmount = (_amount * totalLP) / contractBalance;
            user.LPDepositedRatio += _adjustedAmount;
            totalLP += _adjustedAmount;
        }

        user.userWeight += _amount;
        totalWeight += _amount;

        emit LpDeposited(msg.sender, _amount);
    }

    /**
     * @dev External function to withdraw lp token from the teller. This function can be called by only provider.
     * @param _amount LP token amount
     */
    function withdraw(uint256 _amount) external isProvider nonReentrant {
        Provider storage user = providerInfo[msg.sender];
        uint256 contractBalance = LpToken.balanceOf(address(this));
        if (user.commitmentEndTime <= block.timestamp) {
            user.committedAmount = 0;
            user.commitmentIndex = 0;
        }
        uint256 userTokens = (user.LPDepositedRatio * contractBalance) /
            totalLP;
        require(
            userTokens - user.committedAmount >= _amount,
            "Teller: Provider hasn't got enough deposited LP tokens to withdraw."
        );
        claim();
        uint256 _weightChange = (_amount * user.userWeight) / userTokens;
        user.userWeight -= _weightChange;
        totalWeight -= _weightChange;

        uint256 oldRatio = user.LPDepositedRatio;
        uint256 newRatio = ((userTokens - _amount) * (totalLP - oldRatio)) /
            (contractBalance - _amount);

        totalLP = totalLP - oldRatio + newRatio;
        user.LPDepositedRatio = newRatio;

        LpToken.safeTransfer(msg.sender, _amount);

        emit Withdrew(msg.sender, _amount);
    }

    /**
     * @dev External function to withdraw lp token when teller is closed. This function can be called by only provider.
     */
    function tellerClosedWithdraw() external isTellerClosed isProvider {
        uint256 contractBalance = LpToken.balanceOf(address(this));
        require(contractBalance != 0, "Teller: Contract balance is zero.");

        claim();

        Provider memory user = providerInfo[msg.sender];

        uint256 userTokens = (user.LPDepositedRatio * contractBalance) /
            totalLP;
        totalLP -= user.LPDepositedRatio;
        totalWeight -= user.userWeight;

        delete providerInfo[msg.sender];

        LpToken.safeTransfer(msg.sender, userTokens);

        emit Withdrew(msg.sender, userTokens);
    }

    /**
     * @dev External function to commit lp token to gain a minor advantise for a selected amount of time. This function can be called by only provider.
     * @param _amount LP token amount
     * @param _commitmentIndex Index of commitment array
     */
    function commit(uint256 _amount, uint256 _commitmentIndex)
        external
        nonReentrant
        isProvider
    {
        require(
            commitmentInfo[_commitmentIndex].isActive,
            "Teller: Current commitment is not active."
        );

        Provider storage user = providerInfo[msg.sender];

        if (user.committedAmount != 0) {
            require(
                _commitmentIndex == user.commitmentIndex,
                "Teller: Current commitment is not same as provider."
            );
        }

        uint256 newEndTime;

        if (
            user.commitmentEndTime >= block.timestamp &&
            user.committedAmount != 0
        ) {
            newEndTime = calculateNewEndTime(
                user.committedAmount,
                _amount,
                user.commitmentEndTime,
                _commitmentIndex
            );
        } else {
            user.committedAmount = 0;
            user.commitmentIndex = 0;
            newEndTime =
                block.timestamp +
                commitmentInfo[_commitmentIndex].duration;
        }

        uint256 contractBalance = LpToken.balanceOf(address(this));
        uint256 userTokens = (user.LPDepositedRatio * contractBalance) /
            totalLP;

        require(
            userTokens - user.committedAmount >= _amount,
            "Teller: Provider hasn't got enough deposited LP tokens to commit."
        );

        uint256 weightToGain = (_amount * user.userWeight) / userTokens;
        uint256 bonusCredit = commitBonus(_commitmentIndex, weightToGain);

        claim();
        user.commitmentIndex = _commitmentIndex;
        user.committedAmount += _amount;
        user.commitmentEndTime = newEndTime;
        user.userWeight += bonusCredit;
        totalWeight += bonusCredit;

        emit Commited(msg.sender, _amount);
    }

    /**
     * @dev External function to break the commitment. This function can be called by only provider.
     */
    function breakCommitment() external nonReentrant isProvider {
        Provider memory user = providerInfo[msg.sender];

        require(
            user.commitmentEndTime > block.timestamp,
            "Teller: No commitment to break."
        );

        uint256 contractBalance = LpToken.balanceOf(address(this));

        uint256 tokenToReceive = (user.LPDepositedRatio * contractBalance) /
            totalLP;

        Commitment memory currentCommit = commitmentInfo[user.commitmentIndex];

        uint256 fee = (user.committedAmount * currentCommit.penalty) /
            currentCommit.deciAdjustment;

        tokenToReceive -= fee;

        totalLP -= user.LPDepositedRatio;

        totalWeight -= user.userWeight;

        delete providerInfo[msg.sender];

        if (purpose) {
            LpToken.safeTransfer(devAddress, fee / 10);
        }

        LpToken.safeTransfer(msg.sender, tokenToReceive);

        emit CommitmentBroke(msg.sender, tokenToReceive);
    }

    /**
     * @dev Private function to claim the vidya token.
     */
    function claim() private {
        Provider storage user = providerInfo[msg.sender];
        //Determines if commitment is over, added here since claim is called in every function.
        if (user.commitmentEndTime <= block.timestamp) {
            user.committedAmount = 0;
            user.commitmentIndex = 0;
        }

        uint256 timeGap = block.timestamp - user.lastClaimedTime;

        if (!tellerOpen) {
            timeGap = tellerClosedTime - user.lastClaimedTime;
        }

        if (timeGap > 365 * 1 days) {
            timeGap = 365 * 1 days;
        }

        uint256 timeWeight = timeGap * user.userWeight;

        user.lastClaimedTime = block.timestamp;

        Vault.payProvider(msg.sender, timeWeight, totalWeight);

        emit Claimed(msg.sender, true);
    }

    /**
     * @dev Private function to return commit bonus.
     * @param _commitmentIndex Index of commitment array
     * @param _amount Commitment token amount
     */
    function commitBonus(uint256 _commitmentIndex, uint256 _amount)
        private
        view
        returns (uint256)
    {
        if (commitmentInfo[_commitmentIndex].isActive) {
            return
                (commitmentInfo[_commitmentIndex].bonus * _amount) /
                commitmentInfo[_commitmentIndex].deciAdjustment;
        }
        return 0;
    }

    /**
     * @dev Private function to calculate the new ending time when the current end time is overflown.
     * @param _oldAmount Commitment lp token amount which provider has
     * @param _extraAmount Lp token amount which user wants to commit
     * @param _oldEndTime Previous commitment ending time
     * @param _commitmentIndex Index of commitment array
     */
    function calculateNewEndTime(
        uint256 _oldAmount,
        uint256 _extraAmount,
        uint256 _oldEndTime,
        uint256 _commitmentIndex
    ) private view returns (uint256) {
        uint256 extraEndTIme = commitmentInfo[_commitmentIndex].duration +
            block.timestamp;
        uint256 newEndTime = ((_oldAmount * _oldEndTime) +
            (_extraAmount * extraEndTIme)) / (_oldAmount + _extraAmount);

        return newEndTime;
    }

    /**
     * @dev External function to claim the vidya token. This function can be called by only provider and teller must be opened.
     */
    function claimExternal() external isTellerOpen isProvider nonReentrant {
        claim();
    }

    /**
     * @dev External function to get user LpTokens owned.
     */
    function userLPTokens() external view returns (uint256) {
        return
            (providerInfo[msg.sender].LPDepositedRatio *
                LpToken.balanceOf(address(this))) / totalLP;
    }
}

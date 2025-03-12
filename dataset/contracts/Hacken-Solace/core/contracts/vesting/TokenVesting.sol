// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/Governable.sol";
import "../interfaces/vesting/ITokenVesting.sol";

/**
 * @title TokenVesting
 * @author solace.fi
 * @notice Stores and handles vested [**SOLACE**](./SOLACE) tokens for SOLACE investors.
 *
 * Predetermined agreement with investors for a linear unlock over three years starting 29 Nov 2021, with a six month cliff.
 * We use a Unix timestamp of 1638209176 for the vestingStart, using the following transaction as our reference - https://etherscan.io/tx/0x71f1de15ee75f414c454aec3612433d0123e44ec5987515fc3566795cd840bc3
 */

 contract TokenVesting is ITokenVesting, ReentrancyGuard, Governable {
 
    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice SOLACE Token.
    address public override solace;

    /// @notice timestamp that investor tokens start vesting.
    uint256 immutable public override vestingStart;

    /// @notice timestamp that investor tokens finish vesting.
    uint256 immutable public override vestingEnd;

    /// @notice Total tokens allocated to an investor.
    mapping(address => uint256) public override totalInvestorTokens;

    /// @notice Claimed token amount for an investor.
    mapping(address => uint256) public override claimedInvestorTokens;

    /**
     * @notice Constructs the `InvestorVesting` contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param solace_ Address of [**SOLACE**](./SOLACE).
     * @param vestingStart_ Unix timestamp for start of vesting period for investor tokens.
     */
    constructor(address governance_, address solace_, uint256 vestingStart_) Governable(governance_) {
        require(solace_ != address(0x0), "zero address solace");
        require(vestingStart_ > 0, "vestingStart must > 0");
        solace = solace_;
        vestingStart = vestingStart_;
        vestingEnd = vestingStart_ + 94608000; // Vesting ends 3-years after vesting start.
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Get vesting duration in seconds
     */
    function duration() public view override returns (uint256) {
        return vestingEnd - vestingStart;
    }


    /***************************************
    INVESTOR FUNCTIONS
    ***************************************/

    /**
     * @notice Function for investor to claim SOLACE tokens - transfers all claimable tokens from contract to msg.sender.
     */
    function claimTokens() external override nonReentrant {
        require(totalInvestorTokens[msg.sender] > 0, "no tokens allocated");
        uint256 claimableTokens = getClaimableTokens(msg.sender);
        require(claimableTokens > 0, "no claimable tokens");
        claimedInvestorTokens[msg.sender] += claimableTokens;
        SafeERC20.safeTransfer(IERC20(solace), msg.sender, claimableTokens);
        emit TokensClaimed(solace, msg.sender, claimableTokens);
    }

    /**
     * @notice Calculates the amount of unlocked SOLACE tokens an investor can claim.
     * @param investor Investor address.
     * @return claimableAmount The amount of unlocked tokens an investor can claim from the smart contract.
     */
    function getClaimableTokens(address investor) public view override returns (uint256 claimableAmount) {
        uint256 timestamp = block.timestamp;
        if(timestamp <= vestingStart) {
            return 0;
        // Within vesting period
        } else if(timestamp > vestingStart && timestamp <= vestingEnd) {
            uint256 totalUnlockedAmount = ( totalInvestorTokens[investor] * (timestamp - vestingStart) / (vestingEnd - vestingStart) );
            claimableAmount = totalUnlockedAmount - claimedInvestorTokens[investor];
            return claimableAmount;
        // After vesting period
        } else {
            claimableAmount = totalInvestorTokens[investor] - claimedInvestorTokens[investor];
            return claimableAmount;
        }
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Rescues excess [**SOLACE**](./SOLACE).
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Trusting governance to perform accurate accounting off-chain and ensure there is sufficient SOLACE in contract to make payouts as dictated in totalInvestorTokens mapping.
     * @param amount Amount to send.
     * @param recipient Address to send rescued SOLACE tokens to.
     */
    function rescueSOLACEtokens(uint256 amount, address recipient) external override onlyGovernance {
        require(recipient != address(0x0), "zero address recipient");
        SafeERC20.safeTransfer(IERC20(solace), recipient, amount);
        emit TokensRescued(solace, recipient, amount);
    }

    /**
     * @notice Sets the total SOLACE token amounts that investors are eligible for.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Trusting governance to perform accurate accounting off-chain and ensure there is sufficient SOLACE in contract to make payouts as dictated in totalInvestorTokens mapping.
     * @param investors Array of investors to set.
     * @param totalTokenAmounts Array of token amounts to set.
     */
    function setTotalInvestorTokens(address[] calldata investors, uint256[] calldata totalTokenAmounts) external override onlyGovernance {
        require(investors.length == totalTokenAmounts.length, "length mismatch");
        for(uint256 i = 0; i < investors.length; i++) {
            totalInvestorTokens[investors[i]] = totalTokenAmounts[i];
            emit TotalInvestorTokensSet(investors[i], totalTokenAmounts[i]);
        }
    }

    /**
     * @notice Changes address for an investor.
     * @dev Transfers vesting history to another address
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param oldAddress Old investor address.
     * @param newAddress New investor address.
     */
    function setNewInvestorAddress(address oldAddress, address newAddress) external override onlyGovernance {
        // Require these guards to avoid overwriting pre-existing key-value pairs in the totalInvestorTokens and claimedInvestorTokens mappings
        require(totalInvestorTokens[newAddress] == 0, "Cannot set to a pre-existing address");
        require(claimedInvestorTokens[newAddress] == 0, "Cannot set to a pre-existing address");
        totalInvestorTokens[newAddress] = totalInvestorTokens[oldAddress];
        claimedInvestorTokens[newAddress] = claimedInvestorTokens[oldAddress];
        totalInvestorTokens[oldAddress] = 0;
        claimedInvestorTokens[oldAddress] = 0; // Transfer vesting history to another address
        emit InvestorAddressChanged(oldAddress, newAddress);
        emit TotalInvestorTokensSet(oldAddress, 0);
        emit TotalInvestorTokensSet(newAddress, totalInvestorTokens[newAddress]);
    }
 }

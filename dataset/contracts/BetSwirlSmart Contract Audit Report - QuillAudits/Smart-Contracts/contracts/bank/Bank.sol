// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import {IReferral} from "./IReferral.sol";

// import "hardhat/console.sol";

/// @title BetSwirl's Bank
/// @author Romuald Hog
/// @notice The Bank contract holds the casino's funds,
/// whitelist the games betting tokens,
/// define the max bet amount based on a risk,
/// payout the bet profit to user and collect the loss bet amount from the game's contract,
/// split and allocate the house edge taken from each bet (won or loss),
/// manage the tokens balance overflow to dynamically send overflowed tokens to the treasury and team.
/// The admin role is transfered to a Timelock that execute administrative tasks,
/// only the Games could payout the bet profit from the bank, and send the loss bet amount to the bank.
/// @dev All rates are in basis point.
contract Bank is AccessControl, KeeperCompatibleInterface {
    using SafeERC20 for IERC20;

    /// @notice Enum to identify the Chainlink Upkeep registration.
    enum UpkeepActions {
        ManageBalanceOverflow,
        DistributePartnerHouseEdge,
        DistributeReferralHouseEdge
    }

    /// @notice Token's house edge allocations struct.
    /// The games house edge is split into several allocations.
    /// The allocated amounts stays in the bank until authorized parties withdraw. They are subtracted from the balance.
    /// @param dividend Rate to be allocated as staking rewards, on bet payout.
    /// @param referral Rate to be allocated to the referrers, on bet payout.
    /// @param partner Rate to be allocated to the partner, on bet payout.
    /// @param treasury Rate to be allocated to the treasury, on bet payout.
    /// @param team Rate to be allocated to the team, on bet payout.
    /// @param dividendAmount The number of tokens to be sent as staking rewards.
    /// @param partnerAmount The number of tokens to be sent to the partner.
    /// @param treasuryAmount The number of tokens to be sent to the treasury.
    /// @param teamAmount The number of tokens to be sent to the team.
    /// @param referralAmount The number of tokens to be sent to the referral program contract.
    /// @param minPartnerTransferAmount The minimum amount of token to distribute the partner house edge.
    struct HouseEdgeSplit {
        uint16 dividend;
        uint16 referral;
        uint16 partner;
        uint16 treasury;
        uint16 team;
        uint256 dividendAmount;
        uint256 partnerAmount;
        uint256 treasuryAmount;
        uint256 teamAmount;
        uint256 referralAmount;
        uint256 minPartnerTransferAmount;
    }

    /// @notice Token's balance overflow struct.
    /// @param thresholdRate Threshold rate for the token's balance reference.
    /// @param toTreasury Rate to be allocated to the treasury.
    /// @param toTeam Rate to be allocated to the team.
    struct BalanceOverflow {
        uint16 thresholdRate;
        uint16 toTreasury;
        uint16 toTeam;
    }

    /// @notice Token struct.
    /// List of tokens to bet on games.
    /// @param allowed Whether the token is allowed for bets.
    /// @param balanceRisk Defines the maximum bank payout, used to calculate the max bet amount.
    /// @param partner Address of the partner to manage the token and receive the house edge.
    /// @param houseEdgeSplit House edge allocations.
    /// @param balanceReference Balance reference used to manage the bank overflow.
    /// @param balanceOverflow Balance overflow management configuration.
    struct Token {
        bool allowed;
        uint16 balanceRisk;
        address partner;
        HouseEdgeSplit houseEdgeSplit;
        uint256 balanceReference;
        BalanceOverflow balanceOverflow;
    }

    /// @notice Token's metadata struct. It contains additional information from the ERC20 token.
    /// @dev Only used on the `getTokens` getter for the front-end.
    /// @param decimals Number of token's decimals.
    /// @param tokenAddress Contract address of the token.
    /// @param name Name of the token.
    /// @param symbol Symbol of the token.
    /// @param token Token data.
    struct TokenMetadata {
        uint8 decimals;
        address tokenAddress;
        string name;
        string symbol;
        Token token;
    }

    /// @notice Number of tokens added.
    uint16 public tokensCount;

    /// @notice Chainlink Keeper Registry address.
    address public keeperRegistry;

    /// @notice Treasury multi-sig wallet.
    address payable public immutable treasury;

    /// @notice Team wallet.
    address payable public teamWallet;

    /// @notice Referral program contract.
    IReferral public referralProgram;

    /// @notice Role associated to Games smart contracts.
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    /// @notice Role associated to SwirlMaster smart contract.
    bytes32 public constant SWIRLMASTER_ROLE = keccak256("SWIRLMASTER_ROLE");

    /// @notice Maps tokens addresses to token configuration.
    mapping(address => Token) public tokens;

    /// @notice Maps tokens indexes to token address.
    mapping(uint16 => address) public tokensList;

    /// @notice Emitted after the team wallet is set.
    /// @param teamWallet The team wallet address.
    event SetTeamWallet(address teamWallet);

    /// @notice Emitted after the referral program is set.
    /// @param referralProgram The referral program address.
    event SetReferralProgram(address referralProgram);

    /// @notice Emitted after a token is added.
    /// @param token Address of the token.
    event AddToken(address token);

    /// @notice Emitted after the balance risk is set.
    /// @param balanceRisk Rate defining the balance risk.
    event SetBalanceRisk(address indexed token, uint16 balanceRisk);

    /// @notice Emitted after a token is allowed.
    /// @param token Address of the token.
    /// @param allowed Whether the token is allowed for betting.
    event SetAllowedToken(address indexed token, bool allowed);

    /// @notice Emitted after the Upkeep minimum transfer amount is set.
    /// @param token Address of the token.
    /// @param minPartnerTransferAmount Minimum amount of token to allow transfer.
    event SetMinPartnerTransferAmount(
        address indexed token,
        uint256 minPartnerTransferAmount
    );

    /// @notice Emitted after a token partner is set.
    /// @param token Address of the token.
    /// @param partner Address of the partner.
    event SetTokenPartner(address indexed token, address partner);

    /// @notice Emitted after a token deposit.
    /// @param token Address of the token.
    /// @param amount The number of token deposited.
    event Deposit(address indexed token, uint256 amount);

    /// @notice Emitted after a token withdrawal.
    /// @param token Address of the token.
    /// @param amount The number of token withdrawn.
    event Withdraw(address indexed token, uint256 amount);

    /// @notice Emitted after the Chainlink Keeper Registry is set.
    /// @param keeperRegistry Address of the Keeper Registry.
    event SetKeeperRegistry(address keeperRegistry);

    /// @notice Emitted after the token's house edge allocations for bet payout is set.
    /// @param token Address of the token.
    /// @param dividend Rate to be allocated as staking rewards, on bet payout.
    /// @param referral Rate to be allocated to the referrers, on bet payout.
    /// @param partner Rate to be allocated to the partner, on bet payout.
    /// @param treasury Rate to be allocated to the treasury, on bet payout.
    /// @param team Rate to be allocated to the team, on bet payout.
    event SetTokenHouseEdgeSplit(
        address indexed token,
        uint16 dividend,
        uint16 referral,
        uint16 partner,
        uint16 treasury,
        uint16 team
    );

    /// @notice Emitted after the token's treasury and team allocations are distributed.
    /// @param token Address of the token.
    /// @param treasuryAmount The number of tokens sent to the treasury.
    /// @param teamAmount The number of tokens sent to the team.
    event HouseEdgeDistribution(
        address indexed token,
        uint256 treasuryAmount,
        uint256 teamAmount
    );
    /// @notice Emitted after the token's partner allocation is distributed.
    /// @param token Address of the token.
    /// @param partnerAmount The number of tokens sent to the partner.
    event HouseEdgePartnerDistribution(
        address indexed token,
        uint256 partnerAmount
    );
    /// @notice Emitted after the token's referral allocation is distributed.
    /// @param token Address of the token.
    /// @param referralProgram The address of the Referral Program contract.
    /// @param referralAmount The number of tokens sent.
    event DistributeReferralAmount(
        address indexed token,
        address referralProgram,
        uint256 referralAmount
    );

    /// @notice Emitted after the token's dividend allocation is distributed.
    /// @param token Address of the token.
    /// @param amount The number of tokens sent to the SwirlMaster.
    event HarvestDividend(address indexed token, uint256 amount);

    /// @notice Emitted after the token's balance overflow management configuration is set.
    /// @param token Address of the token.
    /// @param thresholdRate Threshold rate for the token's balance reference.
    /// @param toTreasury Rate to be allocated to the treasury.
    /// @param toTeam Rate to be allocated to the team.
    event SetBalanceOverflow(
        address indexed token,
        uint16 thresholdRate,
        uint16 toTreasury,
        uint16 toTeam
    );

    /// @notice Emitted after the token's bank overflow amount is distributed to the treasury and team.
    /// @param token Address of the token.
    /// @param amountToTreasury The number of tokens sent to the treasury.
    /// @param amountToTeam The number of tokens sent to the team.
    event BankOverflowTransfer(
        address indexed token,
        uint256 amountToTreasury,
        uint256 amountToTeam
    );

    /// @notice Emitted after the token's balance reference is set.
    /// This happends on deposit, withdraw and when the bank overflow threashold is reached.
    /// @param token Address of the token.
    /// @param balanceReference New balance reference used to determine the bank overflow.
    event SetBalanceReference(address indexed token, uint256 balanceReference);

    /// @notice Emitted after the token's house edge is allocated.
    /// @param token Address of the token.
    /// @param dividend The number of tokens allocated as staking rewards.
    /// @param referral The number of tokens allocated to the referrers.
    /// @param partner The number of tokens allocated to the partner.
    /// @param treasury The number of tokens allocated to the treasury.
    /// @param team The number of tokens allocated to the team.
    event AllocateHouseEdgeAmount(
        address indexed token,
        uint256 dividend,
        uint256 referral,
        uint256 partner,
        uint256 treasury,
        uint256 team
    );

    /// @notice Emitted after the bet profit amount is sent to the user.
    /// @param token Address of the token.
    /// @param newBalance New token balance.
    /// @param profit Bet profit amount sent.
    event Payout(address indexed token, uint256 newBalance, uint256 profit);

    /// @notice Emitted after the bet amount is collected from the game smart contract.
    /// @param token Address of the token.
    /// @param newBalance New token balance.
    /// @param amount Bet amount collected.
    event CashIn(address indexed token, uint256 newBalance, uint256 amount);

    /// @notice Reverting error when trying to add an existing token.
    /// @param token Address of the token.
    error TokenExists(address token);
    /// @notice Reverting error when setting the house edge allocations, but the sum isn't 100%.
    /// @param splitSum Sum of the house edge allocations rates.
    error WrongHouseEdgeSplit(uint16 splitSum);
    /// @notice Reverting error when setting wrong balance overflow management configuration.
    error WrongBalanceOverflow();
    /// @notice Reverting error when sender isn't allowed.
    error AccessDenied();
    /// @notice Reverting error when referral program or team wallet is the zero address.
    error WrongAddress();

    /// @notice Modifier that checks that an account is allowed to interact.
    /// @param role The required role.
    /// @param token The token address.
    modifier onlyTokenOwner(bytes32 role, address token) {
        address partner = tokens[token].partner;
        if (partner == address(0)) {
            _checkRole(role, msg.sender);
        } else if (msg.sender != partner) {
            revert AccessDenied();
        }
        _;
    }

    /// @notice Initialize the contract's admin role to the deployer, and state variables.
    /// @param treasuryAddress Treasury multi-sig wallet.
    /// @param teamWalletAddress Team wallet.
    /// @param referralProgramAddress The referral program.
    constructor(
        address payable treasuryAddress,
        address payable teamWalletAddress,
        IReferral referralProgramAddress
    ) {
        // The ownership should then be transfered to the Timelock.
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        treasury = treasuryAddress;
        setTeamWallet(teamWalletAddress);
        setReferralProgram(referralProgramAddress);
    }

    /// @notice Transfers a specific amount of token to an address.
    /// Uses native transfer or ERC20 transfer depending on the token.
    /// @dev The 0x address is considered the gas token.
    /// @param user Address of destination.
    /// @param token Address of the token.
    /// @param amount Number of tokens.
    function _safeTransfer(
        address payable user,
        address token,
        uint256 amount
    ) private {
        if (_isGasToken(token)) {
            Address.sendValue(user, amount);
        } else {
            IERC20(token).safeTransfer(user, amount);
        }
    }

    /// @notice Sets the new token's balance reference.
    /// @param token Address of the token.
    /// @param newReference Balance amount corresponding to the new reference.
    function _setBalanceReference(address token, uint256 newReference) private {
        tokens[token].balanceReference = newReference;
        emit SetBalanceReference(token, newReference);
    }

    /// @notice Check if the token has the 0x address.
    /// @param token Address of the token.
    /// @return Whether the token's address is the 0x address.
    function _isGasToken(address token) private pure returns (bool) {
        return token == address(0);
    }

    /// @notice Deposit funds in the bank to allow gamers to win more.
    /// It is also setting the new balance reference, used to manage the bank overflow.
    /// ERC20 token allowance should be given prior to deposit.
    /// @param token Address of the token.
    /// @param amount Number of tokens.
    function deposit(address token, uint256 amount)
        external
        payable
        onlyTokenOwner(DEFAULT_ADMIN_ROLE, token)
    {
        uint256 balance = getBalance(token);
        if (_isGasToken(token)) {
            _setBalanceReference(token, balance);
            amount = msg.value;
        } else {
            _setBalanceReference(token, balance + amount);
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        emit Deposit(token, amount);
    }

    /// @notice Withdraw funds from the bank to migrate.
    /// It is also setting the new balance reference, used to manage the bank overflow.
    /// @param token Address of the token.
    /// @param amount Number of tokens.
    function withdraw(address token, uint256 amount)
        external
        onlyTokenOwner(DEFAULT_ADMIN_ROLE, token)
    {
        _setBalanceReference(token, getBalance(token) - amount);
        _safeTransfer(payable(msg.sender), token, amount);
        emit Withdraw(token, amount);
    }

    /// @notice Sets the keeper registry address
    /// @param keeperRegistryAddress Chainlink Keeper Registry.
    function setKeeperRegistry(address keeperRegistryAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (keeperRegistryAddress != keeperRegistry) {
            keeperRegistry = keeperRegistryAddress;
            emit SetKeeperRegistry(keeperRegistryAddress);
        }
    }

    /// @notice Sets the new token balance risk.
    /// @param token Address of the token.
    /// @param balanceRisk Risk rate.
    function setBalanceRisk(address token, uint16 balanceRisk)
        external
        onlyTokenOwner(DEFAULT_ADMIN_ROLE, token)
    {
        tokens[token].balanceRisk = balanceRisk;
        emit SetBalanceRisk(token, balanceRisk);
    }

    /// @notice Adds a new token that'll be enabled for the games' betting.
    /// Token shouldn't exist yet.
    /// @param token Address of the token.
    function addToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokensCount != 0) {
            for (uint16 i; i < tokensCount; i++) {
                if (tokensList[i] == token) {
                    revert TokenExists(token);
                }
            }
        }
        tokensList[tokensCount] = token;
        tokensCount += 1;
        emit AddToken(token);
    }

    /// @notice Changes the token's bet permission on an already added token.
    /// @param token Address of the token.
    /// @param allowed Whether the token is enabled for bets.
    function setAllowedToken(address token, bool allowed)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokens[token].allowed = allowed;
        emit SetAllowedToken(token, allowed);
    }

    /// @notice Changes the token's Upkeep min transfer amount.
    /// @param token Address of the token.
    /// @param minPartnerTransferAmount Minimum amount of token to allow transfer.
    function setMinPartnerTransferAmount(
        address token,
        uint256 minPartnerTransferAmount
    ) external onlyTokenOwner(DEFAULT_ADMIN_ROLE, token) {
        tokens[token]
            .houseEdgeSplit
            .minPartnerTransferAmount = minPartnerTransferAmount;
        emit SetMinPartnerTransferAmount(token, minPartnerTransferAmount);
    }

    /// @notice Changes the token's partner address.
    /// @param token Address of the token.
    /// @param partner Address of the partner.
    function setTokenPartner(address token, address partner)
        external
        onlyTokenOwner(DEFAULT_ADMIN_ROLE, token)
    {
        tokens[token].partner = partner;
        emit SetTokenPartner(token, partner);
    }

    /// @notice Sets the token's house edge allocations for bet payout.
    /// @param token Address of the token.
    /// @param dividend Rate to be allocated as staking rewards, on bet payout.
    /// @param referral Rate to be allocated to the referrers, on bet payout.
    /// @param _treasury Rate to be allocated to the treasury, on bet payout.
    /// @param team Rate to be allocated to the team, on bet payout.
    /// @dev `dividend`, `referral`, `_treasury` and `team` rates sum must equals 10000.
    function setHouseEdgeSplit(
        address token,
        uint16 dividend,
        uint16 referral,
        uint16 partner,
        uint16 _treasury,
        uint16 team
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint16 splitSum = dividend + team + partner + _treasury + referral;
        if (splitSum != 10000) {
            revert WrongHouseEdgeSplit(splitSum);
        }

        HouseEdgeSplit storage tokenHouseEdge = tokens[token].houseEdgeSplit;
        tokenHouseEdge.dividend = dividend;
        tokenHouseEdge.referral = referral;
        tokenHouseEdge.partner = partner;
        tokenHouseEdge.treasury = _treasury;
        tokenHouseEdge.team = team;

        emit SetTokenHouseEdgeSplit(
            token,
            dividend,
            referral,
            partner,
            _treasury,
            team
        );
    }

    /// @notice Sets the token's balance overflow management configuration.
    /// The threshold shouldn't exceed 100% to be able to calculate the overflowed amount.
    /// The treasury and team rates sum shouldn't exceed 100% to allow the bank balance to grow organically.
    /// @param token Address of the token.
    /// @param thresholdRate Threshold rate for the token's balance reference.
    /// @param toTreasury Rate to be allocated to the treasury.
    /// @param toTeam Rate to be allocated to the team.
    function setBalanceOverflow(
        address token,
        uint16 thresholdRate,
        uint16 toTreasury,
        uint16 toTeam
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (thresholdRate > 10000 || (toTreasury + toTeam) > 10000) {
            revert WrongBalanceOverflow();
        }

        tokens[token].balanceOverflow = BalanceOverflow(
            thresholdRate,
            toTreasury,
            toTeam
        );
        emit SetBalanceOverflow(token, thresholdRate, toTreasury, toTeam);
    }

    /// @notice Harvests tokens dividends.
    /// @return The list of tokens addresses.
    /// @return The list of tokens' amounts harvested.
    function harvestDividends()
        external
        onlyRole(SWIRLMASTER_ROLE)
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _tokens = new address[](tokensCount);
        uint256[] memory _amounts = new uint256[](tokensCount);

        for (uint16 i; i < tokensCount; i++) {
            address tokenAddress = tokensList[i];
            Token storage token = tokens[tokenAddress];
            uint256 dividendAmount = token.houseEdgeSplit.dividendAmount;
            if (dividendAmount != 0) {
                token.houseEdgeSplit.dividendAmount = 0;
                _safeTransfer(
                    payable(msg.sender),
                    tokenAddress,
                    dividendAmount
                );
                emit HarvestDividend(tokenAddress, dividendAmount);
                _tokens[i] = tokenAddress;
                _amounts[i] = dividendAmount;
            }
        }

        return (_tokens, _amounts);
    }

    /// @notice Get the available tokens dividends amounts.
    /// @return The list of tokens addresses.
    /// @return The list of tokens' amounts harvested.
    function getDividends()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _tokens = new address[](tokensCount);
        uint256[] memory _amounts = new uint256[](tokensCount);

        for (uint16 i; i < tokensCount; i++) {
            address tokenAddress = tokensList[i];
            Token storage token = tokens[tokenAddress];
            uint256 dividendAmount = token.houseEdgeSplit.dividendAmount;
            if (dividendAmount > 0) {
                _tokens[i] = tokenAddress;
                _amounts[i] = dividendAmount;
            }
        }

        return (_tokens, _amounts);
    }

    /// @notice Payouts a winning bet, and allocate the house edge fee.
    /// @param user Address of the gamer.
    /// @param token Address of the token.
    /// @param profit Number of tokens to be sent to the gamer.
    /// @param fees Bet amount and bet profit fees amount.
    function payout(
        address payable user,
        address token,
        uint256 profit,
        uint256 fees
    ) external payable onlyRole(GAME_ROLE) {
        // Splits the house edge fees and allocates them as dividends, for referrers, to the partner, the treasury, and team.
        // If the user has no referrer, the referral allocation is allocated evenly among the other allocations.
        {
            HouseEdgeSplit storage tokenHouseEdge = tokens[token]
                .houseEdgeSplit;

            // Calculate the referral allocation
            uint256 referralAllocation = (fees * tokenHouseEdge.referral) /
                10000;
            uint256 referralAmount;
            if (referralAllocation != 0) {
                referralAmount = referralProgram.payReferral(
                    user,
                    token,
                    referralAllocation
                );
                referralAllocation -= referralAmount;
            }
            uint256 dividendAmount = (fees * tokenHouseEdge.dividend) / 10000;
            uint256 partnerAmount = (fees * tokenHouseEdge.partner) / 10000;
            uint256 treasuryAmount = (fees * tokenHouseEdge.treasury) / 10000;
            uint256 teamAmount = (fees * tokenHouseEdge.team) / 10000;

            uint8 allocationsCount;
            if (dividendAmount != 0) {
                allocationsCount++;
            }
            if (partnerAmount != 0) {
                allocationsCount++;
            }
            if (treasuryAmount != 0) {
                allocationsCount++;
            }
            if (teamAmount != 0) {
                allocationsCount++;
            }

            uint256 referralAllocationRestPerSplit;
            if (allocationsCount != 0) {
                referralAllocationRestPerSplit =
                    (referralAllocation -
                        (referralAllocation % allocationsCount)) /
                    allocationsCount;
            }

            if (dividendAmount != 0) {
                dividendAmount += referralAllocationRestPerSplit;
                tokenHouseEdge.dividendAmount += dividendAmount;
            }
            if (partnerAmount != 0) {
                partnerAmount += referralAllocationRestPerSplit;
                tokenHouseEdge.partnerAmount += partnerAmount;
            }
            if (treasuryAmount != 0) {
                treasuryAmount += referralAllocationRestPerSplit;
                tokenHouseEdge.treasuryAmount += treasuryAmount;
            }
            if (teamAmount != 0) {
                teamAmount += referralAllocationRestPerSplit;
                tokenHouseEdge.teamAmount += teamAmount;
            }

            if (referralAmount != 0) {
                // If no registered Chainlink Keepers, transfer to the referral program.
                if (keeperRegistry == address(0)) {
                    _safeTransfer(
                        payable(address(referralProgram)),
                        token,
                        referralAmount
                    );
                } else {
                    tokenHouseEdge.referralAmount += referralAmount;
                }
            }

            emit AllocateHouseEdgeAmount(
                token,
                dividendAmount,
                referralAmount,
                partnerAmount,
                treasuryAmount,
                teamAmount
            );
        }

        // Pay the user
        _safeTransfer(user, token, profit);
        emit Payout(token, getBalance(token), profit);
    }

    /// @notice Accounts a loss bet.
    /// @dev In case of an ERC20, the bet amount should be transfered prior to this tx.
    /// @dev In case of the gas token, the bet amount is sent along with this tx.
    /// @param tokenAddress Address of the token.
    /// @param amount Loss bet amount.
    function cashIn(address tokenAddress, uint256 amount)
        external
        payable
        onlyRole(GAME_ROLE)
    {
        emit CashIn(
            tokenAddress,
            getBalance(tokenAddress),
            _isGasToken(tokenAddress) ? msg.value : amount
        );
    }

    /// @notice Executed by Chainlink Keepers when `upkeepNeeded` is true.
    /// @param performData Data which was passed back from `checkUpkeep`.
    function performUpkeep(bytes calldata performData) external override {
        if (msg.sender != keeperRegistry) {
            revert AccessDenied();
        }
        (UpkeepActions upkeepAction, address tokenAddress) = abi.decode(
            performData,
            (UpkeepActions, address)
        );
        HouseEdgeSplit memory houseEdgeSplit = tokens[tokenAddress]
            .houseEdgeSplit;

        if (upkeepAction == UpkeepActions.ManageBalanceOverflow) {
            manageBalanceOverflow(tokenAddress);
        } else if (
            upkeepAction == UpkeepActions.DistributePartnerHouseEdge &&
            houseEdgeSplit.partnerAmount >
            houseEdgeSplit.minPartnerTransferAmount
        ) {
            withdrawPartnerAmount(tokenAddress);
        } else if (
            upkeepAction == UpkeepActions.DistributeReferralHouseEdge &&
            houseEdgeSplit.referralAmount > 0
        ) {
            withdrawReferralAmount(tokenAddress);
        }
    }

    /// @dev For the front-end
    function getTokens() external view returns (TokenMetadata[] memory) {
        TokenMetadata[] memory _tokens = new TokenMetadata[](tokensCount);
        for (uint16 i; i < tokensCount; i++) {
            address tokenAddress = tokensList[i];
            Token memory token = tokens[tokenAddress];
            if (_isGasToken(tokenAddress)) {
                _tokens[i] = TokenMetadata({
                    decimals: 18,
                    tokenAddress: tokenAddress,
                    name: "ETH",
                    symbol: "ETH",
                    token: token
                });
            } else {
                IERC20Metadata erc20Metadata = IERC20Metadata(tokenAddress);
                _tokens[i] = TokenMetadata({
                    decimals: erc20Metadata.decimals(),
                    tokenAddress: tokenAddress,
                    name: erc20Metadata.name(),
                    symbol: erc20Metadata.symbol(),
                    token: token
                });
            }
        }
        return _tokens;
    }

    /// @notice Calculates the max bet amount based on the token balance, the balance risk, and the game multiplier.
    /// @param token Address of the token.
    /// @param multiplier The bet amount leverage determines the user's profit amount. 10000 = 100% = no profit.
    /// @return Maximum bet amount for the token.
    /// @dev The multiplier should be at least 10000.
    function getMaxBetAmount(address token, uint256 multiplier)
        external
        view
        returns (uint256)
    {
        return (getBalance(token) * tokens[token].balanceRisk) / multiplier;
    }

    /// @notice Gets the token's allow status used on the games smart contracts.
    /// @param token Address of the token.
    /// @return Whether the token is enabled for bets.
    function isAllowedToken(address token) external view returns (bool) {
        return tokens[token].allowed;
    }

    /// @notice Runs by Chainlink Keepers at every block to determine if `performUpkeep` should be called.
    /// @param checkData Fixed and specified at Upkeep registration.
    /// @return upkeepNeeded Boolean that when True will trigger the on-chain performUpkeep call.
    /// @return performData Bytes that will be used as input parameter when calling performUpkeep.
    /// @dev `checkData` and `performData` are encoded with types (uint8, address).
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (UpkeepActions upkeepAction, address tokenAddressData) = abi.decode(
            checkData,
            (UpkeepActions, address)
        );
        if (upkeepAction == UpkeepActions.DistributePartnerHouseEdge) {
            HouseEdgeSplit memory houseEdgeSplit = tokens[tokenAddressData]
                .houseEdgeSplit;
            if (
                houseEdgeSplit.partnerAmount >
                houseEdgeSplit.minPartnerTransferAmount
            ) {
                upkeepNeeded = true;
                performData = abi.encode(upkeepAction, tokenAddressData);
            }
        } else {
            for (uint16 i; i < tokensCount; i++) {
                address tokenAddress = tokensList[i];
                Token memory token = tokens[tokenAddress];
                HouseEdgeSplit memory houseEdgeSplit = token.houseEdgeSplit;
                if (
                    upkeepAction == UpkeepActions.ManageBalanceOverflow &&
                    token.partner == address(0)
                ) {
                    uint256 tokenBalance = getBalance(tokenAddress);
                    uint256 overflow = (token.balanceReference +
                        ((tokenBalance * token.balanceOverflow.thresholdRate) /
                            10000));
                    if (tokenBalance > overflow) {
                        upkeepNeeded = true;
                        performData = abi.encode(upkeepAction, tokenAddress);
                        break;
                    }
                } else if (
                    upkeepAction == UpkeepActions.DistributeReferralHouseEdge &&
                    houseEdgeSplit.referralAmount > 0
                ) {
                    upkeepNeeded = true;
                    performData = abi.encode(upkeepAction, tokenAddress);
                }
            }
        }
    }

    /// @notice Sets the new team wallet.
    /// @param _teamWallet The team wallet address.
    function setTeamWallet(address payable _teamWallet)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_teamWallet == address(0)) {
            revert WrongAddress();
        }
        teamWallet = _teamWallet;
        emit SetTeamWallet(teamWallet);
    }

    /// @notice Sets the new referral program.
    /// @param _referralProgram The referral program address.
    function setReferralProgram(IReferral _referralProgram)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (address(_referralProgram) == address(0)) {
            revert WrongAddress();
        }
        referralProgram = _referralProgram;
        emit SetReferralProgram(address(referralProgram));
    }

    /// @notice Manages the balance overflow.
    /// @notice When the bank overflow threshold amount is reached on a token balance,
    /// the bank sends a percentage to the treasury and team, and the new token's balance reference is set.
    /// @param tokenAddress Address of the token.
    function manageBalanceOverflow(address tokenAddress) public {
        Token storage token = tokens[tokenAddress];
        uint256 tokenBalance = getBalance(tokenAddress);
        uint256 overflow = (token.balanceReference +
            ((tokenBalance * token.balanceOverflow.thresholdRate) / 10000));
        if (token.partner == address(0) && tokenBalance > overflow) {
            uint256 diff = tokenBalance - token.balanceReference;
            uint256 overflowAmountToTreasury = ((diff *
                token.balanceOverflow.toTreasury) / 10000);
            uint256 overflowAmountToTeam = ((diff *
                token.balanceOverflow.toTeam) / 10000);
            _setBalanceReference(
                tokenAddress,
                tokenBalance - overflowAmountToTreasury - overflowAmountToTeam
            );

            uint256 treasuryAmount = token.houseEdgeSplit.treasuryAmount;
            uint256 teamAmount = token.houseEdgeSplit.teamAmount;
            token.houseEdgeSplit.treasuryAmount = 0;
            token.houseEdgeSplit.teamAmount = 0;

            _safeTransfer(
                treasury,
                tokenAddress,
                treasuryAmount + overflowAmountToTreasury
            );
            _safeTransfer(
                teamWallet,
                tokenAddress,
                teamAmount + overflowAmountToTeam
            );
            emit BankOverflowTransfer(
                tokenAddress,
                treasuryAmount + overflowAmountToTreasury,
                teamAmount + overflowAmountToTeam
            );
        }
    }

    /// @notice Distributes the token's treasury and team allocations amounts.
    /// @param tokenAddress Address of the token.
    function withdrawHouseEdgeAmount(address tokenAddress) public {
        HouseEdgeSplit storage tokenHouseEdge = tokens[tokenAddress]
            .houseEdgeSplit;
        uint256 treasuryAmount = tokenHouseEdge.treasuryAmount;
        uint256 teamAmount = tokenHouseEdge.teamAmount;
        if (treasuryAmount != 0) {
            tokenHouseEdge.treasuryAmount = 0;
            _safeTransfer(treasury, tokenAddress, treasuryAmount);
        }
        if (teamAmount != 0) {
            tokenHouseEdge.teamAmount = 0;
            _safeTransfer(teamWallet, tokenAddress, teamAmount);
        }
        if (treasuryAmount != 0 || teamAmount != 0) {
            emit HouseEdgeDistribution(
                tokenAddress,
                treasuryAmount,
                teamAmount
            );
        }
    }

    /// @notice Distributes the token's partner amount.
    /// @param tokenAddress Address of the token.
    function withdrawPartnerAmount(address tokenAddress) public {
        Token storage token = tokens[tokenAddress];
        uint256 partnerAmount = token.houseEdgeSplit.partnerAmount;
        if (partnerAmount != 0 && token.partner != address(0)) {
            token.houseEdgeSplit.partnerAmount = 0;
            _safeTransfer(payable(token.partner), tokenAddress, partnerAmount);
            emit HouseEdgePartnerDistribution(tokenAddress, partnerAmount);
        }
    }

    /// @notice Distributes the token's referral amount.
    /// @param tokenAddress Address of the token.
    function withdrawReferralAmount(address tokenAddress) public {
        HouseEdgeSplit storage tokenHouseEdge = tokens[tokenAddress]
            .houseEdgeSplit;
        uint256 referralAmount = tokenHouseEdge.referralAmount;
        if (referralAmount != 0) {
            address referralProgramAddress = address(referralProgram);
            tokenHouseEdge.referralAmount = 0;
            _safeTransfer(
                payable(referralProgramAddress),
                tokenAddress,
                referralAmount
            );
            emit DistributeReferralAmount(
                tokenAddress,
                referralProgramAddress,
                referralAmount
            );
        }
    }

    /// @notice Gets the token's balance.
    /// The token's house edge allocation amounts are subtracted from the balance.
    /// @param token Address of the token.
    /// @return The amount of token available for profits.
    function getBalance(address token) public view returns (uint256) {
        uint256 balance;
        if (_isGasToken(token)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
        HouseEdgeSplit memory tokenHouseEdgeSplit = tokens[token]
            .houseEdgeSplit;
        return
            balance -
            tokenHouseEdgeSplit.dividendAmount -
            tokenHouseEdgeSplit.partnerAmount -
            tokenHouseEdgeSplit.treasuryAmount -
            tokenHouseEdgeSplit.teamAmount -
            tokenHouseEdgeSplit.referralAmount;
    }
}

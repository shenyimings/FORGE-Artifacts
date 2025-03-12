// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libs/MinerTypes.sol";
import "../interfaces/IBlockValidator.sol";
import "../interfaces/IMinerList.sol";
import "../interfaces/IMinerFormulas.sol";
import "../helpers/RolesHandler.sol";

/**
 * @title Metaminer
 * @dev A smart contract representing a Metaminer,
 * allowing users to stake and participate in block validation.
 */
contract Metaminer is Initializable, RolesHandler {
    /// @notice a struct that hold share for distribution
    struct Share {
        uint256 sharedPercent;
        uint256 shareHolderCount;
    }
    /// @notice shareholder payload for distribution
    struct Shareholder {
        address addr;
        uint256 percent;
    }

    /// @notice BlockValidator instance address
    IBlockValidator public blockValidator;
    /// @notice MinerList instance address
    IMinerList public minerList;
    /// @notice MinerFormulas instance address
    IMinerFormulas public minerFormulas;
    /// @notice needed stake amount for being metaminer
    uint256 public constant STAKE_AMOUNT = 1_000_000 ether;
    /// @notice annual metaminer rental fee
    uint256 public constant ANNUAL_AMOUNT = 100_000 ether;
    /// @notice year in seconds
    uint256 private constant YEAR = 31536000;
    /// @notice address of MinerPool contract
    address private minerPool;

    /// @notice a mapping that holds each addresses' shares
    mapping(address => Share) public shares;
    /// @notice a mapping that holds miners' subscription dates
    mapping(address => uint256) public minerSubscription;
    /// @notice a mapping that holds shareholders for each address
    mapping(address => mapping(uint256 => Shareholder)) public shareholders;

    /// @notice miner is added
    event MinerAdded(address indexed miner, uint256 indexed validDate);
    /// @notice miner is subscribed
    event MinerSubscribe(address indexed miner, uint256 indexed newValidDate);
    /// @notice miner is unsubscribed
    event MinerUnsubscribe(address indexed miner);

    /**
     * @dev Modifier to check if an address is a Metaminer.
     * @param miner The address to check.
     */
    modifier isMiner(address miner) {
        require(
            minerList.isMiner(miner, MinerTypes.NodeType.Meta),
            "Metaminer: Address is not metaminer"
        );
        _;
    }

    /**
     * @dev Modifier to check if a Metaminer's subscription is valid.
     * @param miner The address of the Metaminer to check.
     */
    modifier validMinerSubscription(address miner) {
        require(
            minerSubscription[miner] > block.timestamp,
            "Metaminer: Miner subscription is not as required"
        );
        _;
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     */
    receive() external payable {}

    /**
     * @dev Initializes the Metaminer contract with the addresses of the
     * BlockValidator, MinerList, MinerFormulas, and MinerPool contracts.
     * @param blockValidatorAddress The address of the BlockValidator contract.
     * @param minerListAddress The address of the MinerList contract.
     * @param minerFormulasAddress The address of the MinerFormulas contract.
     * @param minerPoolAddress The address of the MinerPool contract.
     */
    function initialize(
        address blockValidatorAddress,
        address minerListAddress,
        address minerFormulasAddress,
        address minerPoolAddress
    ) external initializer {
        require(
            blockValidatorAddress != address(0) &&
                minerListAddress != address(0) &&
                minerFormulasAddress != address(0) &&
                minerPoolAddress != address(0),
            "Metaminer: cannot set zero address"
        );
        blockValidator = IBlockValidator(blockValidatorAddress);
        minerList = IMinerList(minerListAddress);
        minerFormulas = IMinerFormulas(minerFormulasAddress);
        minerPool = minerPoolAddress;
    }

    /**
     * @dev Allows a user to become a Metaminer
     * by staking the required amount of MTC.
     * @return A boolean indicating whether the operation was successful.
     */
    function setMiner() external payable returns (bool) {
        require(
            msg.value == (ANNUAL_AMOUNT + STAKE_AMOUNT),
            "Metaminer: Required MTC is not sent"
        );
        shares[msg.sender] = Share(0, 0);
        minerSubscription[msg.sender] = _nextYear(msg.sender);
        minerList.addMiner(msg.sender, MinerTypes.NodeType.Meta);
        _addShareHolder(
            msg.sender,
            minerPool,
            minerFormulas.METAMINER_MINER_POOL_SHARE_PERCENT()
        );
        emit MinerAdded(msg.sender, minerSubscription[msg.sender]);
        return (true);
    }

    /**
     * @dev Allows a Metaminer to renew their subscription
     * for another year by sending the required amount of MTC.
     * @return A boolean indicating whether the operation was successful.
     */
    function subscribe() external payable isMiner(msg.sender) returns (bool) {
        require(
            msg.value == ANNUAL_AMOUNT,
            "Metaminer: Required MTC was not sent"
        );
        minerSubscription[msg.sender] = _nextYear(msg.sender);
        emit MinerSubscribe(msg.sender, minerSubscription[msg.sender]);
        return (true);
    }

    /**
     * @dev Allows a Metaminer to unsubscribe by unstaking their funds.
     * @return A boolean indicating whether the operation was successful.
     */
    function unsubscribe() external isMiner(msg.sender) returns (bool) {
        _unsubscribe(msg.sender);
        emit MinerUnsubscribe(msg.sender);
        return (true);
    }

    /**
     * @dev Allows the contract owner to set a Metaminer by address.
     * @return A boolean indicating whether the operation was successful.
     */
    function setValidator(
        address validator
    ) external onlyOwnerRole(msg.sender) returns (bool) {
        require(
            validator != address(0),
            "Metaminer: Validator cannot be zero address"
        );
        shares[validator] = Share(0, 0);
        minerSubscription[validator] = _nextYear(validator);
        minerList.addMiner(validator, MinerTypes.NodeType.Meta);
        _addShareHolder(
            validator,
            minerPool,
            minerFormulas.METAMINER_MINER_POOL_SHARE_PERCENT()
        );
        emit MinerAdded(validator, minerSubscription[validator]);
        return (true);
    }

    /**
     * @dev Allows the contract owner to refresh the subscription of a Metaminer.
     * @return A boolean indicating whether the operation was successful.
     */
    function refreshValidator(
        address validator
    ) external onlyOwnerRole(msg.sender) isMiner(validator) returns (bool) {
        minerSubscription[validator] = _nextYear(validator);
        return (true);
    }

    /**
     * @dev Allows the contract owner to set the percentage share for Metaminer's shareholders.
     * @param miner The address of the Metaminer.
     * @param shareholders_ The addresses of the shareholders.
     * @param percentages The corresponding percentages for the shareholders.
     * @return A boolean indicating whether the operation was successful.
     */
    function setPercentages(
        address miner,
        address[] memory shareholders_,
        uint256[] memory percentages
    ) external onlyOwnerRole(msg.sender) isMiner(miner) returns (bool) {
        Share storage share = shares[miner];
        uint256 shareholdersLength = shareholders_.length;
        for (uint256 i = 0; i < shareholdersLength; i++) {
            address addr = shareholders_[i];
            uint256 percentage = percentages[i];
            uint256 nextPercent = share.sharedPercent + percentage;

            require(
                addr != address(0),
                "Metaminer: Shareholder cannot set zero address"
            );
            require(
                percentage != 0,
                "Metaminer: Shareholder percentage cannot be zero"
            );
            require(
                nextPercent <= minerFormulas.BASE_DIVIDER(),
                "Metaminer: Total percent cannot exceed 100"
            );

            _addShareHolder(miner, addr, percentage);
            share.sharedPercent = nextPercent;
        }
        return (true);
    }

    /**
     * @dev Allows a Metaminer to finalize a block and distribute rewards.
     * @param blockNumber The block number to finalize.
     * @return A boolean indicating whether the operation was successful.
     */
    function finalizeBlock(
        uint256 blockNumber
    ) external payable returns (bool) {
        bool status = _minerCheck(msg.sender);

        if (!status) {
            return false;
        }

        IBlockValidator.BlockPayload memory blockPayload = blockValidator
            .blockPayloads(blockNumber);
        bool finalized = blockPayload.isFinalized;
        require(finalized == false, "Metaminer: Already finalized");
        address coinbase = blockPayload.coinbase;
        uint256 blockReward = blockPayload.blockReward;

        require(msg.sender == coinbase, "Metaminer: Wrong coinbase");
        require(msg.value >= blockReward, "Metaminer: Insufficient amount");

        _shareIncome(msg.sender, msg.value);

        blockValidator.finalizeBlock(blockNumber);

        return true;
    }

    /**
     * @dev Calculates the timestamp for next year.
     * @param miner The address of the Metaminer.
     * @return The timestamp for next year.
     */
    function _nextYear(address miner) internal view returns (uint256) {
        return (
            minerSubscription[miner] > block.timestamp
                ? (minerSubscription[miner] + YEAR)
                : (block.timestamp + YEAR)
        );
    }

    /**
     * @dev Adds a shareholder to a Metaminer's list of shareholders.
     * @param miner The address of the Metaminer.
     * @param shareholder The address of the shareholder to add.
     * @param percentage The percentage share of the shareholder.
     */
    function _addShareHolder(
        address miner,
        address shareholder,
        uint256 percentage
    ) internal isMiner(miner) {
        Share storage share = shares[miner];
        shareholders[miner][share.shareHolderCount] = Shareholder(
            shareholder,
            percentage
        );
        share.shareHolderCount++;
    }

    /**
     * @dev Distributes the income to the Metaminer's shareholders.
     * @param miner The address of the Metaminer.
     * @param balance The total balance to distribute.
     * @return A boolean indicating whether the operation was successful.
     */
    function _shareIncome(
        address miner,
        uint256 balance
    ) internal isMiner(miner) validMinerSubscription(miner) returns (bool) {
        uint256 _shareholderCount = shares[miner].shareHolderCount;
        for (uint256 i = 0; i < _shareholderCount; i++) {
            Shareholder memory shareHolder = shareholders[miner][i];
            uint256 holderPercent = (balance * shareHolder.percent) /
                minerFormulas.BASE_DIVIDER();
            (bool sent, ) = address(shareHolder.addr).call{
                value: holderPercent
            }("");
            require(sent, "Metaminer: Income sharing failed");
        }
        return (true);
    }

    /**
     * @dev Unsubscribes a Metaminer by transferring their staked amount back to them,
     * but not annual subscription amount.
     * @param miner The address of the Metaminer to unsubscribe.
     * @return A boolean indicating whether the operation was successful.
     */
    function _unsubscribe(address miner) internal returns (bool) {
        (bool sent, ) = address(miner).call{value: STAKE_AMOUNT}("");
        require(sent, "Metaminer: Unsubsribe failed");
        minerList.deleteMiner(miner, MinerTypes.NodeType.Meta);
        minerSubscription[miner] = 0;
        // must be delete old shareholders
        return (true);
    }

    /**
     * @dev Checks if a Metaminer's subscription is valid and unsubscribe them if it's not.
     * @param miner The address of the Metaminer to check.
     * @return A boolean indicating whether the Metaminer's subscription is valid.
     */
    function _minerCheck(address miner) internal isMiner(miner) returns (bool) {
        if (minerSubscription[miner] < block.timestamp) {
            _unsubscribe(miner);
            return (false);
        } else {
            return (true);
        }
    }
}

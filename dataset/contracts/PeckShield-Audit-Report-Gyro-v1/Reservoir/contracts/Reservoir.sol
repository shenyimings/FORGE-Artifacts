pragma solidity ^0.7.5;

import "./libs/SafeMath.sol";
import "./libs/Address.sol";
import "./libs/Ownable.sol";
import "./libs/IERC20.sol";
import "./libs/SafeERC20.sol";

import "./interfaces/IGyro.sol";
import "./interfaces/IGyroBond.sol";

import "./interfaces/IReservoir.sol";

interface IERC20Mintable {
    function mint(uint256 amount_) external;

    function mint(address account_, uint256 ammount_) external;
}

contract Reservoir is IReservoir, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum TARGETS {
        COLLATERAL_TOKEN,
        BOND,
        DEPOSITOR,
        SPENDER,
        DEBTOR,
        COLLATERAL_MANAGER,
        LIQUIDITY_MANAGER,
        REWARD_MANAGER,
        S_GYRO
    }

    event LogDeposit(address indexed token, uint256 amount, uint256 value);
    event LogWithdraw(address indexed token, uint256 amount, uint256 value);
    event LogCreateDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
    event LogRepayDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
    event LogManageAssets(address indexed token, uint256 amount);
    event LogUpdateAssets(uint256 indexed totalAssets);
    event LogAuditAssets(uint256 indexed totalAssets);
    event LogMintRewards(address indexed caller, address indexed recipient, uint256 amount);
    event LogQueueChange(TARGETS indexed target, address queued);
    event LogActivateChange(TARGETS indexed target, address activated, bool result);

    address public immutable gyro;
    uint256 public immutable queueLength; // in blocks

    address[] public collateralTokens;
    mapping(address => uint256) public collateralTokenQueue; // Delays changes to mapping.

    address[] public bonds;
    mapping(address => uint256) public bondQueue; // Delays changes to mapping.

    address[] public depositors;
    mapping(address => uint256) public depositorQueue; // Delays changes to mapping.

    address[] public spenders;
    mapping(address => uint256) public spenderQueue; // Delays changes to mapping.

    address[] public debtors;
    mapping(address => uint256) public debtorQueue; // Delays changes to mapping.
    mapping(address => uint256) public debtorBalances;

    address[] public collateralManagers;
    mapping(address => uint256) public collateralManagerQueue; // Delays changes to mapping.

    address[] public liquidityManagers;
    mapping(address => uint256) public liquidityManagerQueue; // Delays changes to mapping.

    address[] public rewardManagers; // rewardManager => token
    mapping(address => uint256) public rewardManagerQueue; // Delays changes to mapping.

    address public sGyro;
    uint256 public sGyroQueue; // Delays change to sGyro address

    uint256 public totalAssets; // Risk-free value of all assets
    uint256 public totalDebt;

    modifier validate(address bond_) {
        require(bond_ != address(0), "Bond undefined");
        require(_listContains(bonds, bond_), "Bond not accepted");
        _;
    }

    modifier isDepositor() {
        require(_listContains(depositors, msg.sender), "Not approved");
        _;
    }

    modifier isSpender() {
        require(_listContains(spenders, msg.sender), "Not approved");
        _;
    }

    modifier isDebtor() {
        require(_listContains(debtors, msg.sender), "Not approved");
        _;
    }

    modifier isRewardManager() {
        require(_listContains(rewardManagers, msg.sender), "Not approved");
        _;
    }

    constructor(
        address gyro_,
        address collateralToken_,
        uint256 queueLength_
    ) {
        require(gyro_ != address(0), "Gyro undefined");
        gyro = gyro_;

        require(collateralToken_ != address(0), "Collateral undefined");
        collateralTokens.push(collateralToken_);

        queueLength = queueLength_;
    }

    /**
        @notice allow approved address to deposit an asset for gyro
        @param amount_ uint
        @param profit_ uint
        @return send_ uint
     */
    function bondDeposit(uint256 amount_, uint256 profit_)
        external
        override
        validate(msg.sender)
        returns (uint256 send_)
    {
        (uint256 value, address token) = IGyroBond(msg.sender).gyroValue(amount_);
        send_ = _deposit(token, amount_, value, profit_);
    }

    /**
        @notice allow approved address to deposit an asset for gyro
        @param token_ token address
        @param amount_ uint
        @param profit_ uint
        @return send_ uint
     */
    function deposit(
        address token_,
        uint256 amount_,
        uint256 profit_
    ) external override isDepositor() returns (uint256 send_) {
        require(!_listContains(bonds, msg.sender), "Bond not accepted");
        require(_listContains(collateralTokens, token_), "Collateral token only");
        uint256 value = _gyroValueOf(token_, amount_);
        send_ = _deposit(token_, amount_, value, profit_);
    }

    function _deposit(
        address token_,
        uint256 amount_,
        uint256 value,
        uint256 profit_
    ) private returns (uint256 send_) {
        IERC20(token_).safeTransferFrom(msg.sender, address(this), amount_);

        // mint gyro needed and store amount of rewards for distribution
        send_ = value.sub(profit_);
        IERC20Mintable(gyro).mint(msg.sender, send_);

        totalAssets = totalAssets.add(value);
        emit LogUpdateAssets(totalAssets);

        emit LogDeposit(token_, amount_, value);
    }

    /**
        @notice allow approved address to burn gyro for collateral tokens
        @param bond_ address
        @param amount_ uint
     */
    function withdraw(address bond_, uint256 amount_) external isSpender() validate(bond_) {
        (uint256 value, address token) = IGyroBond(bond_).gyroValue(amount_);
        require(_listContains(collateralTokens, token), "Collateral token only");

        IGyro(gyro).burnFrom(msg.sender, value);

        totalAssets = totalAssets.sub(value);
        emit LogUpdateAssets(totalAssets);

        IERC20(token).safeTransfer(msg.sender, amount_);

        emit LogWithdraw(token, amount_, value);
    }

    /**
        @notice allow approved address to borrow collateral tokens
        @param bond_ address
        @param amount_ uint
     */
    function incurDebt(address bond_, uint256 amount_) external isDebtor() validate(bond_) {
        require(sGyro != address(0), "sGyro undefined");

        (uint256 value, address token) = IGyroBond(bond_).gyroValue(amount_);
        require(_listContains(collateralTokens, token), "Collateral token only");

        uint256 maximumDebt = IERC20(sGyro).balanceOf(msg.sender); // Can only borrow against sGyro held
        uint256 availableDebt = maximumDebt.sub(debtorBalances[msg.sender]);
        require(value <= availableDebt, "Exceeds debt limit");

        debtorBalances[msg.sender] = debtorBalances[msg.sender].add(value);
        totalDebt = totalDebt.add(value);

        totalAssets = totalAssets.sub(value);
        emit LogUpdateAssets(totalAssets);

        IERC20(token).safeTransfer(msg.sender, amount_);

        emit LogCreateDebt(msg.sender, token, amount_, value);
    }

    /**
        @notice allow approved address to repay borrowed collaterals with collateral tokens
        @param bond_ address
        @param amount_ uint
     */
    function repayDebtWithCollateral(address bond_, uint256 amount_) external isDebtor() validate(bond_) {
        (uint256 value, address token) = IGyroBond(bond_).gyroValue(amount_);
        require(_listContains(collateralTokens, token), "Collateral token only");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount_);

        debtorBalances[msg.sender] = debtorBalances[msg.sender].sub(value);
        totalDebt = totalDebt.sub(value);

        totalAssets = totalAssets.add(value);
        emit LogUpdateAssets(totalAssets);

        emit LogRepayDebt(msg.sender, token, amount_, value);
    }

    /**
        @notice allow approved address to repay borrowed collaterals with gyro
        @param amount_ uint
     */
    function repayDebtWithGyro(uint256 amount_) external isDebtor() {
        IGyro(gyro).burnFrom(msg.sender, amount_);

        debtorBalances[msg.sender] = debtorBalances[msg.sender].sub(amount_);
        totalDebt = totalDebt.sub(amount_);

        emit LogRepayDebt(msg.sender, gyro, amount_, amount_);
    }

    /**
        @notice allow approved address to withdraw assets
        @param bond_ address
        @param amount_ uint
     */
    function manage(address bond_, uint256 amount_) external validate(bond_) {
        if (IGyroBond(bond_).isLiquidityBond()) {
            require(_listContains(liquidityManagers, msg.sender), "Not approved");
        } else {
            require(_listContains(collateralManagers, msg.sender), "Not approved");
        }

        (uint256 value, address token) = IGyroBond(bond_).gyroValue(amount_);

        require(value <= excessAssets(), "Insufficient assets");

        totalAssets = totalAssets.sub(value);
        emit LogUpdateAssets(totalAssets);

        IERC20(token).safeTransfer(msg.sender, amount_);

        emit LogManageAssets(token, amount_);
    }

    /**
        @notice send epoch reward to staking contract
     */
    function mintRewards(address recipient_, uint256 amount_) external override isRewardManager() returns (uint256) {
        if (amount_ > excessAssets()) {
            // Not enough profit to create rewards
            emit LogMintRewards(msg.sender, recipient_, 0);
            return 0;
        }

        IERC20Mintable(gyro).mint(recipient_, amount_);

        emit LogMintRewards(msg.sender, recipient_, amount_);

        return amount_;
    }

    /**
        @notice returns excess assets not backing tokens
        @return uint
     */
    function excessAssets() public view returns (uint256) {
        uint256 net = IERC20(gyro).totalSupply().sub(totalDebt);
        if (totalAssets <= net) return 0;
        return totalAssets.sub(net);
    }

    /**
        @notice takes inventory of all tracked assets
        @notice always consolidate to recognized assets before auditing
     */
    function auditAssets() external onlyOwner() {
        uint256 assets;
        uint256 value;
        for (uint256 i = 0; i < bonds.length; i++) {
            IGyroBond bond = IGyroBond(bonds[i]);
            (value, ) = bond.gyroValue(IERC20(bond.tokenIn()).balanceOf(address(this)));
            assets = assets.add(value);
        }

        totalAssets = assets;
        emit LogUpdateAssets(assets);
        emit LogAuditAssets(assets);
    }

    /**
        @notice queue address to change boolean in mapping
        @param target_ TARGETS
        @param address_ address
        @return bool
     */
    function queue(TARGETS target_, address address_) external onlyOwner() returns (bool) {
        require(address_ != address(0));

        if (target_ == TARGETS.COLLATERAL_TOKEN) {
            // 0
            collateralTokenQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.BOND) {
            // 1
            bondQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.DEPOSITOR) {
            // 2
            depositorQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.SPENDER) {
            // 3
            spenderQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.DEBTOR) {
            // 4
            debtorQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.COLLATERAL_MANAGER) {
            // 5
            collateralManagerQueue[address_] = block.number.add(queueLength.mul(2));
        } else if (target_ == TARGETS.LIQUIDITY_MANAGER) {
            // 6
            liquidityManagerQueue[address_] = block.number.add(queueLength.mul(2));
        } else if (target_ == TARGETS.REWARD_MANAGER) {
            // 7
            rewardManagerQueue[address_] = block.number.add(queueLength);
        } else if (target_ == TARGETS.S_GYRO) {
            // 8
            sGyroQueue = block.number.add(queueLength);
        } else return false;

        emit LogQueueChange(target_, address_);
        return true;
    }

    /**
        @notice verify queue then set boolean in mapping
        @param target_ TARGETS
        @param address_ address
        @return bool
     */
    function toggle(TARGETS target_, address address_) external onlyOwner() returns (bool) {
        require(address_ != address(0), "Target address undefined");
        bool result = false;

        if (target_ == TARGETS.COLLATERAL_TOKEN) {
            // 0
            bool isNewToken = !_listContains(collateralTokens, address_);
            if (_ensureQueued(collateralTokenQueue[address_], isNewToken)) {
                collateralTokenQueue[address_] = 0;
                collateralTokens.push(address_);
                result = true;
            } else {
                _removeFromList(collateralTokens, address_);
            }
        } else if (target_ == TARGETS.BOND) {
            // 1
            bool isNewBond = !_listContains(bonds, address_);
            if (_ensureQueued(bondQueue[address_], isNewBond)) {
                bondQueue[address_] = 0;
                bonds.push(address_);
                result = true;
            } else {
                _removeFromList(bonds, address_);
            }
        } else if (target_ == TARGETS.DEPOSITOR) {
            // 2
            bool isNewDepositor = !_listContains(depositors, address_);

            if (_ensureQueued(depositorQueue[address_], isNewDepositor)) {
                depositorQueue[address_] = 0;
                depositors.push(address_);
                result = true;
            } else {
                _removeFromList(depositors, address_);
            }
        } else if (target_ == TARGETS.SPENDER) {
            // 3
            bool isNewSpender = !_listContains(spenders, address_);

            if (_ensureQueued(spenderQueue[address_], isNewSpender)) {
                spenderQueue[address_] = 0;
                spenders.push(address_);
                result = true;
            } else {
                _removeFromList(spenders, address_);
            }
        } else if (target_ == TARGETS.DEBTOR) {
            // 4
            bool isNewDebtor = !_listContains(debtors, address_);
            if (_ensureQueued(debtorQueue[address_], isNewDebtor)) {
                debtorQueue[address_] = 0;
                debtors.push(address_);
                result = true;
            } else {
                _removeFromList(debtors, address_);
            }
        } else if (target_ == TARGETS.COLLATERAL_MANAGER) {
            // 5
            bool isNewManager = !_listContains(collateralManagers, address_);
            if (_ensureQueued(collateralManagerQueue[address_], isNewManager)) {
                collateralManagerQueue[address_] = 0;
                collateralManagers.push(address_);
                result = true;
            } else {
                _removeFromList(collateralManagers, address_);
            }
        } else if (target_ == TARGETS.LIQUIDITY_MANAGER) {
            // 6
            bool isNewManager = !_listContains(liquidityManagers, address_);
            if (_ensureQueued(liquidityManagerQueue[address_], isNewManager)) {
                liquidityManagerQueue[address_] = 0;
                liquidityManagers.push(address_);
                result = true;
            } else {
                _removeFromList(liquidityManagers, address_);
            }
        } else if (target_ == TARGETS.REWARD_MANAGER) {
            // 7
            bool isNewManager = !_listContains(rewardManagers, address_);

            if (_ensureQueued(rewardManagerQueue[address_], isNewManager)) {
                rewardManagerQueue[address_] = 0;
                rewardManagers.push(address_);
                result = true;
            } else {
                _removeFromList(rewardManagers, address_);
            }
        } else if (target_ == TARGETS.S_GYRO) {
            // 8
            sGyroQueue = 0;
            sGyro = address_;
            result = true;
        } else return false;

        emit LogActivateChange(target_, address_, result);
        return true;
    }

    /**
        @notice checks requirements and returns altered structs
        @param queueLength_ uint
        @param notSet_ bool
        @return bool 
     */
    function _ensureQueued(uint256 queueLength_, bool notSet_) internal view returns (bool) {
        if (notSet_) {
            require(queueLength_ != 0, "Must queue");
            require(queueLength_ <= block.number, "Queue not expired");
            return true;
        }
        return false;
    }

    /**
        @notice checks array to ensure against duplicate
        @param list_ address[]
        @param token_ address
        @return bool
     */
    function _listContains(address[] storage list_, address token_) internal view returns (bool) {
        for (uint256 i = 0; i < list_.length; i++) {
            if (list_[i] == token_) {
                return true;
            }
        }
        return false;
    }

    /**
        @notice remove the element from the list
        @param list_ address[]
        @param el_ address
        @return uint256
     */
    function _removeFromList(address[] storage list_, address el_) internal returns (uint256) {
        uint256 i;
        for (i = 0; i < list_.length; i++) {
            if (list_[i] == el_) {
                list_[i] = list_[list_.length - 1];
                delete list_[list_.length - 1];
                list_.pop();
                break;
            }
        }

        return i;
    }

    /**
        @notice only for collateral tokens
        @param token_ address
        @param amount_ uint
        @return value_ uint256
     */
    function _gyroValueOf(address token_, uint256 amount_) internal view returns (uint256 value_) {
        value_ = amount_.mul(10**IERC20(gyro).decimals()).div(10**IERC20(token_).decimals());
    }
}

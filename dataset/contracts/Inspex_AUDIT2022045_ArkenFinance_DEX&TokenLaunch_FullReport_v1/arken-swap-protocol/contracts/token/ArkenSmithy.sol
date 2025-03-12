// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.11;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './ArkenToken.sol';

/// @notice This contract is the only address who can mint new ARKENs.
///     This is designed to be plug-and-rewards with new Arken products,
///         without the logic of LP or staking embedded into it.
///     Which differentiate this from PancakeSwap's MasterChef implementation.
contract ArkenSmithy is Ownable, ReentrancyGuard {
    // Modified from PancakeSwap code:
    // MasterChef: https://github.com/pancakeswap/pancake-smart-contracts/blob/master/projects/farms-pools/contracts/MasterChef.sol
    // MasterChefV2: https://bscscan.com/address/0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652#code

    using SafeERC20 for IERC20;

    struct PoolInfo {
        uint256 lastRewardBlock;
        uint256 endRewardBlock; // zero means no end block
        uint256 accumulatedArken;
        uint256 arkenPerBlock;
    }

    /// @notice The ARKEN Token!
    ArkenToken public ARKEN;

    /// @notice Mint pool
    PoolInfo[] public poolInfos;

    /// @notice Pool admins whom has permission to withdraw ARKEN
    address[] public poolAdmins;

    /// @notice Total sum of ARKEN per block for every pools
    uint256 public totalArkenPerBlock;

    event Init();
    event AddPool(uint256 indexed pid, uint256 arkenPerBlock);
    event SetPool(uint256 indexed pid, uint256 arkenPerBlock);
    event Withdraw(address indexed to, uint256 indexed pid, uint256 amount);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardBlock);
    event UpdatePoolAdmin(
        uint256 indexed pid,
        address indexed oldAdmin,
        address indexed newAdmin
    );

    /// @param _ARKEN The ARKEN token contract address.
    constructor(ArkenToken _ARKEN) {
        ARKEN = _ARKEN;
        // init empty pool
        poolInfos.push(
            PoolInfo({
                arkenPerBlock: 0,
                accumulatedArken: 0,
                lastRewardBlock: block.number,
                endRewardBlock: 0
            })
        );
        poolAdmins.push(msg.sender);
    }

    /// @notice Add a new pool. Can only be called by the owner.
    /// @param _arkenPerBlock ARKEN per block for this pool
    /// @param _startBlock Block to start ARKEN distribution. (0 for current block)
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    /// only for ARKEN distributions within Arken products.
    function add(
        uint256 _arkenPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        address _poolAdmin,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalArkenPerBlock = totalArkenPerBlock + _arkenPerBlock;
        uint256 startBlock = block.number;
        if (_startBlock > 0) {
            startBlock = _startBlock;
        }
        poolInfos.push(
            PoolInfo({
                arkenPerBlock: _arkenPerBlock,
                accumulatedArken: 0,
                lastRewardBlock: startBlock,
                endRewardBlock: _endBlock
            })
        );
        poolAdmins.push(_poolAdmin);
        emit AddPool(poolInfos.length - 1, _arkenPerBlock);
    }

    /// @notice Update the given pool's ARKEN per block.
    /// @param _pid The id of the pool.
    /// @param _arkenPerBlock New number of ARKEN per block.
    /// @param _withUpdate Whether call "massUpdatePools" operation.
    function set(
        uint256 _pid,
        uint256 _arkenPerBlock,
        bool _withUpdate
    ) external onlyOwner {
        // No matter _withUpdate is true or false, we need to execute updatePool once before set the pool parameters.
        updatePool(_pid);
        if (_withUpdate) {
            massUpdatePools();
        }
        totalArkenPerBlock =
            totalArkenPerBlock -
            poolInfos[_pid].arkenPerBlock +
            _arkenPerBlock;
        poolInfos[_pid].arkenPerBlock = _arkenPerBlock;
        emit SetPool(_pid, _arkenPerBlock);
    }

    /// @notice Update pool's admin who can withdraw pending ARKEN.
    /// @param _pid The id of the pool.
    /// @param _newAdmin New pool admin.
    function setPoolAdmin(uint256 _pid, address _newAdmin) external {
        require(
            msg.sender == poolAdmins[_pid] || msg.sender == owner(),
            'ArkenSmithy: NON_AUTHORIZED_POOL_OWNER'
        );
        address _oldAdmin = poolAdmins[_pid];
        poolAdmins[_pid] = _newAdmin;
        emit UpdatePoolAdmin(_pid, _oldAdmin, _newAdmin);
    }

    /// @notice Update multiple ARKEN allocation pools.
    /// @param _pids An array of ids of the pool.
    /// @param _arkenPerBlocks New number of ARKEN per block for each pools.
    function massSet(
        uint256[] calldata _pids,
        uint256[] calldata _arkenPerBlocks,
        bool _withUpdate
    ) external onlyOwner {
        require(
            _pids.length == _arkenPerBlocks.length,
            'ArkenSmithy: MASS_SET_LENGTH_MISMATCH'
        );
        for (uint256 i = 0; i < _pids.length; i++) {
            // No matter _withUpdate is true or false, we need to execute updatePool once before setting the pool parameters.
            updatePool(_pids[i]);
        }
        uint256 newTotalArkenPerBlock = totalArkenPerBlock;
        for (uint256 i = 0; i < _pids.length; i++) {
            uint256 _pid = _pids[i];
            uint256 _arkenPerBlock = _arkenPerBlocks[i];
            newTotalArkenPerBlock =
                newTotalArkenPerBlock -
                poolInfos[_pid].arkenPerBlock +
                _arkenPerBlock;
            poolInfos[_pid].arkenPerBlock = _arkenPerBlock;
            emit SetPool(_pid, _arkenPerBlock);
        }
        totalArkenPerBlock = newTotalArkenPerBlock;
        if (_withUpdate) {
            massUpdatePools();
        }
    }

    /// @notice Update ARKEN reward for all the active pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo memory pool = poolInfos[pid];
            if (pool.arkenPerBlock != 0) {
                updatePool(pid);
            }
        }
    }

    /// @notice Update reward variables for the given pool.
    /// @param _pid The id of the pool. See `poolInfos`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool) {
        pool = poolInfos[_pid];
        if (block.number > pool.lastRewardBlock) {
            pool.accumulatedArken = pendingArken(_pid);
            pool.lastRewardBlock = block.number;
            poolInfos[_pid] = pool;
            emit UpdatePool(_pid, pool.lastRewardBlock);
        }
    }

    /// @notice Pools count.
    function poolsCount() public view returns (uint256) {
        return poolInfos.length;
    }

    /// @notice Arken per block for a pool.
    /// @param _pid The pool id.
    function arkenPerBlock(uint256 _pid) public view returns (uint256) {
        return poolInfos[_pid].arkenPerBlock;
    }

    /// @notice End reward block
    /// @param _pid The pool id.
    function endRewardBlock(uint256 _pid) public view returns (uint256) {
        return poolInfos[_pid].endRewardBlock;
    }

    /// @notice Admin for a pool.
    /// @param _pid The pool id.
    function poolAdmin(uint256 _pid) public view returns (address) {
        return poolAdmins[_pid];
    }

    /// @notice Last reward block for a pool.
    /// @param _pid The pool id.
    function lastRewardBlock(uint256 _pid) public view returns (uint256) {
        return poolInfos[_pid].lastRewardBlock;
    }

    /// @notice Pending ARKEN to be withdraw in the pool.
    /// @param _pid The pool id.
    function pendingArken(uint256 _pid) public view returns (uint256 amount) {
        PoolInfo memory pool = poolInfos[_pid];
        uint256 toBlock = block.number;
        if (pool.endRewardBlock != 0 && pool.endRewardBlock < block.number) {
            toBlock = pool.endRewardBlock;
        }
        amount = pool.accumulatedArken;
        if (pool.lastRewardBlock < toBlock) {
            uint256 multiplier = toBlock - pool.lastRewardBlock;
            amount = amount + (multiplier * pool.arkenPerBlock);
        }
    }

    /// @notice Withdraw all pending ARKEN.
    /// @param _pid The id of the pool.
    function withdraw(
        address _to,
        uint256 _pid,
        uint256 _amount
    ) external nonReentrant {
        require(
            msg.sender == poolAdmins[_pid],
            'ArkenSmithy: NON_AUTHORIZED_POOL_OWNER'
        );
        _settlePendingArken(_to, _pid, _amount);
        emit Withdraw(_to, _pid, _amount);
    }

    /// @notice Settles, distribute the pending ARKEN rewards.
    /// @param _to Address to receive ARKEN.
    /// @param _pid The pool id.
    function _settlePendingArken(
        address _to,
        uint256 _pid,
        uint256 _amount
    ) internal {
        PoolInfo memory pool = updatePool(_pid);
        uint256 pendingAmount = pool.accumulatedArken;
        require(_amount <= pendingAmount, 'ArkenSmithy: SETTLE_EXCEED_PENDING');
        _sendArken(_to, _amount);
        pool.accumulatedArken = pendingAmount - _amount;
        poolInfos[_pid] = pool;
    }

    /// @notice Safe Transfer ARKEN.
    /// @param _to The ARKEN receiver address.
    /// @param _amount transfer ARKEN amounts.
    function _sendArken(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            ARKEN.transfer(_to, _amount);
        }
    }
}

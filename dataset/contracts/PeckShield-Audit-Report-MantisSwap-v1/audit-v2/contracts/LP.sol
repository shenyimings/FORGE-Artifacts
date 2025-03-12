// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import {OwnableUpgradeable as Ownable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable as ERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "./interfaces/ILP.sol";


contract LP is Initializable, Ownable, ERC20, ILP {
    using SafeERC20 for IERC20;

    event PoolSet(address indexed pool, bool status);
    event MasterSet(address indexed oldMaster, address indexed newMaster);
    event AssetUpdated(uint256 oldAmount, uint256 newAmount);
    event LiabilityUpdated(uint256 oldAmount, uint256 newAmount);
    event Minted(address indexed recipient, address indexed user, uint256 amount);
    event Burned(address indexed account, address indexed user, uint256 amount);

    IERC20 public underlier;
    uint256 public asset;
    uint256 public liability;

    uint256 public periodAsset;
    uint256 public periodCounter;

    mapping(address => bool) public pools;
    address public voteManager;

    address public masterMantis;

    uint256 private runningSum;
    uint256 private lastUpdate;
    uint256 private windows;
    uint256 private lastWindowUpdate;

    struct SumHistory {
        uint256 runningSum;
        uint256 duration;
    }

    mapping(uint256 => SumHistory) private sumHistory;
    uint256 private dayIndex;


    modifier onlyPools() {
        require(pools[msg.sender], 'Not Allowed');
        _;
    }

    modifier onlyMaster() {
        require(masterMantis == msg.sender, 'Not Allowed');
        _;
    }

    function initialize(string memory name, string memory symbol, address _underlier, address _pool, address _masterMantis) external initializer {
        require(_underlier != address(0), "Cannot be zero address");
        __Ownable_init_unchained();
        __ERC20_init_unchained(name, symbol);
        underlier = IERC20(_underlier);
        pools[_pool] = true;
        masterMantis = _masterMantis;

        periodCounter = 1;
        lastUpdate = block.timestamp;
        lastWindowUpdate = block.timestamp;
        windows = 10;
    }

    function setPool(address _pool, bool _status) external onlyOwner {
        require(_pool != address(0), "Cannot be zero address");
        pools[_pool] = _status;
        emit PoolSet(_pool, _status);
    }

    function setMasterMantis(address _masterMantis) external onlyOwner {
        require(_masterMantis != address(0), "Cannot be zero address");
        emit MasterSet(masterMantis, _masterMantis);
        masterMantis = _masterMantis;
    }

    function setWindows(uint256 _windows) external onlyOwner {
        require(_windows > 0, "Cannot be 0");
        windows = _windows;
    }

    function approve(address spender, uint256 amount) public override(ERC20, ILP) returns (bool) {
        return super.approve(spender, amount);
    }

    function totalSupply() public view override(ERC20, ILP) returns (uint256) {
        return super.totalSupply();
    }

    function decimals() public view override(ERC20, ILP) returns (uint8) {
        return underlier.decimals();
    }

    function getSumHistory(uint256 index) external view onlyOwner returns (SumHistory memory) {
        return sumHistory[index];
    }

    function getEmissionWeightage() external view override returns (uint256) {
        return (periodAsset * 1e18) / (periodCounter * 10**decimals());
    }

    function getLR() public view override returns (uint256) {
        return liability == 0 ? 1e18 : asset * 1e18 / liability;
    }

    function getMaxLR() public view override returns (uint256 maxLR) {
        uint256 totalSum;
        uint256 totalDuration;
        for (uint256 i = dayIndex > windows ? dayIndex - windows : 0; i < dayIndex; i++) {
            totalSum += sumHistory[i].runningSum;
            totalDuration += sumHistory[i].duration;
        }
        maxLR = (totalSum + runningSum + (getLR() * (block.timestamp - lastUpdate))) / (block.timestamp - lastWindowUpdate + totalDuration);
        if (maxLR < 1e18) {
            maxLR = 1e18;
        }
    }

    function updateAssetLiability(uint256 assetAmount, bool assetIncrease, uint256 liabilityAmount, bool liabilityIncrease) external override onlyPools {
        uint256 oldAsset = asset;
        uint256 oldLiability = liability;
        if (assetAmount > 0) {
            if (assetIncrease) {
                asset += assetAmount;
            } else {
                require(asset >= assetAmount, "Cannot be negative");
                unchecked {
                    asset -= assetAmount;
                }
            }
            emit AssetUpdated(oldAsset, asset);
            periodAsset += asset;
            periodCounter += 1;
        }
        if (liabilityAmount > 0) {
            if (liabilityIncrease) {
                liability += liabilityAmount;
            } else {
                liability -= liabilityAmount;
            }
            emit LiabilityUpdated(oldLiability, liability);
        }

        uint256 oldLR = oldLiability == 0 ? 1e18 : oldAsset * 1e18 / oldLiability;
        runningSum += oldLR * (block.timestamp - lastUpdate);
        lastUpdate = block.timestamp;
        uint256 newLR = getLR();
        uint256 currentMaxLR = getMaxLR();
        if (newLR > currentMaxLR) {
            runningSum = newLR * (block.timestamp - lastWindowUpdate);
            for (uint256 i = dayIndex > windows ? dayIndex - windows : 0; i < dayIndex; i++) {
                sumHistory[i].runningSum = newLR * sumHistory[i].duration;
            }
        }
        uint256 windowDuration = block.timestamp - lastWindowUpdate;
        if (windowDuration >= 1 days) {
            sumHistory[dayIndex] = SumHistory({
                runningSum: runningSum,
                duration: windowDuration
            });
            dayIndex++;
            lastWindowUpdate = block.timestamp;
            runningSum = 0;
        }
    }

    function mint(address recipient, address user, uint256 amount) external override onlyPools {
        _mint(recipient, amount);
        emit Minted(recipient, user, amount);
    }

    function burnFrom(address account, address user, uint256 amount) external override onlyPools {
        if (!pools[account]) {
            uint256 currentAllowance = allowance(account, msg.sender);
            uint256 decreasedAllowance = currentAllowance - amount;
            _approve(account, msg.sender, decreasedAllowance);
        }
        _burn(account, amount);
        emit Burned(account, user, amount);
    }

    function resetPeriod() external override onlyMaster {
        periodAsset = asset;
        periodCounter = 1;
    }

    function withdrawUnderlyer(address recipient, uint256 amount) external override onlyPools {
        underlier.safeTransfer(recipient, amount);
    }
}
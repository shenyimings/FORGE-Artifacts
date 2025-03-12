// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./Interfaces/ICollateralManager.sol";
import "./Interfaces/IEToken.sol";

contract EToken is ERC20Upgradeable, OwnableUpgradeable, IEToken {
    using SafeMathUpgradeable for uint256;

    ICollateralManager internal collateralManager;
    address public tokenAddress;

    mapping(address => uint256) internal shares;

    uint256 private _totalShares;

    function initialize(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init();
        __ERC20_init(name_, symbol_);
    }

    function setAddresses(
        address _collateralManagerAddress,
        address _tokenAddress
    ) external onlyOwner {
        collateralManager = ICollateralManager(_collateralManagerAddress);
        tokenAddress = _tokenAddress;

        emit CollateralManagerAddressChanged(_collateralManagerAddress);
        emit TokenAddressChanged(_tokenAddress);
    }

    function mint(
        address _account,
        uint256 _amount
    ) external override returns (uint256) {
        _requireIsCollateralManager();
        uint256 share = getShare(_amount);
        shares[_account] = shares[_account].add(share);
        _totalShares = _totalShares.add(share);
        _mint(_account, _amount);
        return share;
    }

    function burn(
        address _account,
        uint256 _amount
    ) external override returns (uint256) {
        _requireIsCollateralManager();
        uint256 share = getShare(_amount);
        shares[_account] = shares[_account].sub(share);
        _totalShares = _totalShares.sub(share);
        _burn(_account, share);
        return share;
    }

    function clear(address _account) external override {
        _requireIsCollateralManager();
        uint256 amount = super.balanceOf(_account);
        uint256 share = shares[_account];
        _burn(_account, amount);
        shares[_account] = 0;
        _totalShares = _totalShares.sub(share);
    }

    function reset(
        address _account,
        uint256 _amount
    ) external override returns (uint256) {
        _requireIsCollateralManager();
        uint256 share = getShare(_amount);
        uint256 oldShare = shares[_account];
        uint256 oldAmount = getAmount(oldShare);
        _burn(_account, oldAmount);
        _mint(_account, _amount);
        shares[_account] = share;
        _totalShares = _totalShares.sub(oldShare).add(share);
        return share;
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) public virtual override(IERC20Upgradeable, ERC20Upgradeable) returns (bool) {
        uint256 share = getShare(_amount);
        _requireValidAdjustment(_amount);
        shares[msg.sender] = shares[msg.sender].sub(share);
        _totalShares = _totalShares.sub(share);
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public virtual override(IERC20Upgradeable, ERC20Upgradeable) returns (bool) {
        uint256 share = getShare(_amount);
        _requireValidAdjustment(_amount);
        shares[_sender] = shares[_sender].sub(share);
        _totalShares = _totalShares.sub(share);
        super.transferFrom(_sender, _recipient, _amount);
        return true;
    }

    function sharesOf(address _account) public view override returns (uint256) {
        return shares[_account];
    }

    function getShare(uint256 _amount) public view override returns (uint256) {
        // StETH: return getSharesByPooledEth(uint256 _ethAmount);
        return _amount;
    }

    function getAmount(uint256 _share) public view override returns (uint256) {
        // StETH: return getPooledEthByShares(uint256 _sharesAmount);
        return _share;
    }

    function balanceOf(address _account) public view virtual override(IERC20Upgradeable, ERC20Upgradeable) returns (uint256) {
        return getAmount(sharesOf(_account));
    }

    function totalSupply() public view virtual override(IERC20Upgradeable, ERC20Upgradeable) returns (uint256) {
        return getAmount(_totalShares);
    }

    function _requireIsCollateralManager() internal view {
        require(msg.sender == address(collateralManager), "EToken: Bad caller");
    }

    function _requireValidAdjustment(uint256 _amount) internal view {
        require(
            collateralManager.validAdjustment(
                msg.sender,
                tokenAddress,
                _amount
            ),
            "EToken: Invalid adjustment"
        );
    }
}

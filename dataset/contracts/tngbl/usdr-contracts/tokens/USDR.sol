// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../AddressAccessor.sol";
import "./WadRayMath.sol";
import "../constants/addresses.sol";
import "../constants/constants.sol";
import "../constants/roles.sol";
import "../interfaces/IExchange.sol";
import "../interfaces/IUSDR.sol";

contract USDR is
    IUSDR,
    AddressAccessorUpgradable,
    ERC20PermitUpgradeable,
    PausableUpgradeable
{
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    event Rebase(
        uint256 indexed blockNumber,
        uint256 indexed day,
        uint256 supply,
        uint256 supplyDelta,
        uint256 index
    );

    uint256 private _totalSupply;
    uint256 private _totalSupplyScale;

    uint256 public liquidityIndex;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowedValue;

    function initialize() public initializer {
        liquidityIndex = 10**27;
        __ERC20_init("Real USD", "USDR");
        __ERC20Permit_init("USDR");
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function burn(address account, uint256 amount) external whenNotPaused {
        require(account != address(0), "burn from zero address");

        if (msg.sender != account) {
            _spendAllowance(account, msg.sender, amount);
        }

        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "burn amount exceeds balance");

        if (accountBalance == amount) {
            _totalSupply -= _balances[account];
            delete _balances[account];
        } else {
            uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);
            if (amount_ > _balances[account]) {
                amount_ = _balances[account];
            }
            _totalSupply -= amount_;
            _balances[account] -= amount_;
        }

        emit Transfer(account, address(0), amount);
    }

    function mint(address account, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        require(account != address(0), "mint to zero address");

        uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);

        require(amount_ <= MAX_UINT128 - totalSupply(), "max supply exceeded");

        _totalSupply += amount_;
        _balances[account] += amount_;

        emit Transfer(address(0), account, amount);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    function rebase(uint256 supplyDelta)
        external
        onlyRole(CONTROLLER_ROLE)
        whenNotPaused
    {
        (address treasury, address exchange) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, USDR_EXCHANGE_ADDRESS)
            ),
            (address, address)
        );
        require(msg.sender == treasury, "caller is not treasury");
        uint256 ts = totalSupply();
        if (supplyDelta > 0) {
            supplyDelta = IExchange(exchange).scaleFromUnderlying(supplyDelta);
            uint256 maxSupplyDelta = MAX_UINT128 - ts;
            if (supplyDelta > maxSupplyDelta) {
                supplyDelta = maxSupplyDelta;
            }
            if (supplyDelta > 0) {
                liquidityIndex = (liquidityIndex * (ts + supplyDelta)) / ts;
                int128[7] memory delta;
                delta[6] = int128(uint128(totalSupply() - ts));
                IExchange(exchange).updateMintingStats(delta);
            }
        }
        emit Rebase(
            block.number,
            block.timestamp / 1 days,
            ts,
            supplyDelta,
            liquidityIndex
        );
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    function allowance(address owner_, address spender)
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return _allowedValue[owner_][spender];
    }

    function approve(address spender, uint256 value)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (bool)
    {
        _allowedValue[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function balanceOf(address account)
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return _balances[account].rayMul(liquidityIndex).rayToWad();
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = _allowedValue[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            delete _allowedValue[msg.sender][spender];
        } else {
            _allowedValue[msg.sender][spender] = oldValue - subtractedValue;
        }
        emit Approval(msg.sender, spender, _allowedValue[msg.sender][spender]);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        _allowedValue[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, _allowedValue[msg.sender][spender]);
        return true;
    }

    function totalSupply()
        public
        view
        override(ERC20Upgradeable, IERC20Upgradeable)
        returns (uint256)
    {
        return _totalSupply.rayMul(liquidityIndex).rayToWad();
    }

    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        whenNotPaused
        returns (bool)
    {
        if (amount == balanceOf(msg.sender)) {
            return transferAll(to);
        }
        uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);
        _balances[msg.sender] -= amount_;
        _balances[to] += amount_;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferAll(address to) public whenNotPaused returns (bool) {
        uint256 amount = balanceOf(msg.sender);
        uint256 amount_ = _balances[msg.sender];
        delete _balances[msg.sender];
        _balances[to] += amount_;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferAllFrom(address from, address to)
        public
        whenNotPaused
        returns (bool)
    {
        uint256 amount = balanceOf(from);
        uint256 amount_ = _balances[from];
        _spendAllowance(from, msg.sender, amount);
        delete _balances[from];
        _balances[to] += amount_;
        emit Transfer(from, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(ERC20Upgradeable, IERC20Upgradeable)
        whenNotPaused
        returns (bool)
    {
        if (amount == balanceOf(from)) {
            return transferAllFrom(from, to);
        }
        _spendAllowance(from, msg.sender, amount);
        uint256 amount_ = amount.wadToRay().rayDiv(liquidityIndex);
        _balances[from] -= amount_;
        _balances[to] += amount_;
        emit Transfer(from, to, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual override {
        _allowedValue[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}

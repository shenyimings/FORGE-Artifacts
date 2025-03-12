// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IEIP2612.sol";
import {Governed} from "./Governance.sol";
import {IMintableAndBurnableERC20} from "./interfaces/ERC20.sol";

error ApproveFromZeroAddress(address spender, uint256 amount);
error ApproveToZeroAddress(address owner, uint256 amount);

error MintToZeroAddress(uint256 amount);

error BurnFromZeroAddress(uint256 amount);
error BurnAmountExceedsBalance(address from, uint256 amount, uint256 balance);

error TransferFromZeroAddress(address to, uint256 amount);
error TransferToZeroAddress(address from, uint256 amount);
error TransferAmountExceedsAllowance(address from, address to, uint256 amount, uint256 allowance);
error TransferAmountExceedsBalance(address from, address to, uint256 amount, uint256 balance);

error EIP2612PermissionExpired(uint256 deadline);
error EIP2612InvalidSignature(address owner, address signer);

error MinterZeroAddress();
error OnlyMinterAllowed();

contract BaseToken is Governed, IEIP2612, IMintableAndBurnableERC20 {
    bytes32 private constant EIP_712_DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant PERMIT_TYPE_HASH =
        keccak256("Permit(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");

    string public override name;
    string public override symbol;
    uint8 public override decimals;
    string public version;

    address public minter;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public override DOMAIN_SEPARATOR;
    mapping(address => uint256) public override nonces;

    event MinterChanged(address indexed minter, address indexed newMinter);

    modifier onlyMinter() {
        if (msg.sender != minter) {
            revert OnlyMinterAllowed();
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _minter
    ) {
        setGovernor(msg.sender);

        if (_minter == address(0)) {
            revert MinterZeroAddress();
        }
        minter = _minter;

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        version = "1";
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP_712_DOMAIN_TYPE_HASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        if (from != msg.sender) {
            uint256 _allowance = allowance[from][msg.sender];
            if (_allowance < amount) {
                revert TransferAmountExceedsAllowance(from, to, amount, _allowance);
            }
        }

        _transfer(from, to, amount);

        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);

        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);

        return true;
    }

    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override onlyMinter {
        _burn(from, amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        if (deadline < block.timestamp) {
            revert EIP2612PermissionExpired(deadline);
        }

        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPE_HASH, owner, spender, amount, nonces[owner]++, deadline))
            )
        );
        address signer = ecrecover(hash, v, r, s);
        if (signer != owner) {
            revert EIP2612InvalidSignature(owner, signer);
        }
        _approve(owner, spender, amount);
    }

    function setMinter(address newMinter) external onlyGovernor {
        if (newMinter == address(0)) {
            revert MinterZeroAddress();
        }
        minter = newMinter;
        emit MinterChanged(minter, newMinter);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        if (owner == address(0)) {
            revert ApproveFromZeroAddress(spender, amount);
        }
        if (spender == address(0)) {
            revert ApproveToZeroAddress(owner, amount);
        }

        allowance[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) {
            revert MintToZeroAddress(amount);
        }

        balanceOf[to] += amount;
        totalSupply += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) {
            revert BurnFromZeroAddress(amount);
        }

        uint256 balance = balanceOf[from];
        if (balance < amount) {
            revert BurnAmountExceedsBalance(from, amount, balance);
        }
        unchecked {
            balanceOf[from] = balance - amount;
        }
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from == address(0)) {
            revert TransferFromZeroAddress(to, amount);
        }
        if (to == address(0)) {
            revert TransferToZeroAddress(from, amount);
        }

        uint256 balance = balanceOf[from];
        if (balance < amount) {
            revert TransferAmountExceedsBalance(from, to, amount, balance);
        }
        unchecked {
            balanceOf[from] = balance - amount;
        }
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }
}

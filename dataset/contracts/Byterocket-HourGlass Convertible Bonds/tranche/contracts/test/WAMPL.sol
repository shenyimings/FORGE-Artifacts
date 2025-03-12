// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// @title Test contract that wraps AMPL 1-to-1
contract WAMPL {
    string public name = "Wrapped Ampl";
    string public symbol = "WAMPL";
    uint8 public decimals = 18;
    uint256 public constant MAX_UINT = type(uint256).max;
    address public ampl;

    /**
     * @dev Initializes ERC20 token
     */
    constructor(address _ampl) {
        ampl = _ampl;
    }

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit(uint256 amplAmount) external returns (uint256) {
        SafeERC20.safeTransferFrom(IERC20(ampl), msg.sender, address(this), amplAmount);
        balanceOf[msg.sender] += amplAmount;
        emit Deposit(msg.sender, amplAmount);
        return amplAmount;
    }

    function withdraw(uint256 amplAmount) public {
        require(balanceOf[msg.sender] >= amplAmount, "Insufficient balance");
        balanceOf[msg.sender] -= amplAmount;
        SafeERC20.safeTransfer(IERC20(ampl), msg.sender, amplAmount);
        emit Withdrawal(msg.sender, amplAmount);
    }

    function burn(uint256 wamples) public {
        return withdraw(wamples);
    }

    function totalSupply() public view returns (uint256) {
        return IERC20(ampl).balanceOf(address(this));
    }

    function approve(address other, uint256 amplAmount) public returns (bool) {
        allowance[msg.sender][other] = amplAmount;
        emit Approval(msg.sender, other, amplAmount);
        return true;
    }

    function transfer(address dst, uint256 amplAmount) public returns (bool) {
        return transferFrom(msg.sender, dst, amplAmount);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 amplAmount
    ) public returns (bool) {
        require(balanceOf[src] >= amplAmount, "Insufficient balance");

        if (src != msg.sender && allowance[src][msg.sender] != MAX_UINT) {
            require(allowance[src][msg.sender] >= amplAmount, "Insufficient allowance");
            allowance[src][msg.sender] -= amplAmount;
        }

        balanceOf[src] -= amplAmount;
        balanceOf[dst] += amplAmount;

        emit Transfer(src, dst, amplAmount);

        return true;
    }

    function underlying() external view returns (address) {
        return ampl;
    }

    function wrapperToUnderlying(uint256 wamples) external view returns (uint256) {
        return wamples;
    }
}

// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.7;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address account, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TadNusaSwap is Ownable {
    address public constant tad  = 0x9f7229aF0c4b9740e207Ea283b9094983f78ba04;
    address public constant nusa = 0xe11F1D5EEE6BE945BeE3fa20dBF46FeBBC9F4A19;

    event SwapToken(address indexed sender, uint256 indexed tadAmount, uint256 indexed nusaAmount);

    function withdraw(address payable to) external onlyOwner {
        if ( address(this).balance > 0 ) {
            to.transfer(address(this).balance);
        }
    }
    function withdrawToken(address tokenAddress, address to, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(to, amount);
    }

    function swapToken(uint256 amount) external {
        require(amount > 10, "amount too small");

        // receive TAD
        require(IERC20(tad).transferFrom(msg.sender, address(this), amount), "tad transferFrom failed");

        // mint NUSA
        uint256 nusaAmount = amount / 10;
        require(IERC20(nusa).mint(msg.sender, nusaAmount), "nusa mint failed");

        emit SwapToken(msg.sender, amount, nusaAmount);
    }

    receive() external payable {}
}



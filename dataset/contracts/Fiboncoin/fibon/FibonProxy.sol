pragma solidity ^0.8.0;

import "./Context.sol";
import "./IERC20.sol";
import "./Address.sol";
import "./FibonToken.sol";


contract FibonProxy is Context, IERC20 {
    using Address for address;
    
    
    FibonToken mainContract;
    address owner;
    address mainContractAddress;

    
    constructor () {
        owner = _msgSender();
    }

    function changeMainContract(address newAddress) public virtual returns (bool){
        require(_msgSender() == owner, "ERC20: Unauthorized access.");
        require(newAddress != address(0), "ERC20: proxy contract zero address");
        mainContractAddress = newAddress;
        mainContract = FibonToken(mainContractAddress);
        return true;
    }

    function name() public view returns (string memory) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.name();
    }

    function symbol() public view returns (string memory) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.symbol();
    }
   

    function totalSupply() public view override returns (uint256) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.totalSupply();
    }

    function balanceOf(address account) public view override returns (uint256) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.balanceOf(account);
    }
    
    function frozenUntil(address account) public view override returns (uint256) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.frozenUntil(account);
    }
 
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.transferFrom(_msgSender(), recipient, amount);
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        require(false,"ERC20: not supported");
        return false;
    }

    
}
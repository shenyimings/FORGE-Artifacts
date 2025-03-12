pragma solidity ^0.8.0;

import "./Context.sol";
import "./IERC20Admin.sol";
import "./Address.sol";
import "./FibonToken.sol";


    
    


contract FibonAdmin is Context, IERC20Admin {
    using Address for address;
    
    
    FibonToken mainContract;
    address private owner;
    address private icoTransferAddress;
    address private earlyBackerTransferAddress;
    address private mainContractAddress;

    
    constructor (address icoAddr, address ebAddr) {
            
        owner = _msgSender();
        icoTransferAddress = icoAddr;
        earlyBackerTransferAddress = ebAddr;
       
    }

    function changeMainContract(address newAddress) public virtual returns (bool){
        require(_msgSender() == owner, "ERC20: Unauthorized access.");
        require(newAddress != address(0), "ERC20: proxy contract zero address");
        mainContractAddress = newAddress;
        mainContract = FibonToken(mainContractAddress);
        return true;
        
    }

    function upgradeIcoStage() public virtual override returns (bool) {
        require(_msgSender() == owner, "ERC20: unauthorized access");
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.upgradeIcoStage();
    }

    function setProxyContract(address proxyAddress) public virtual override returns (bool) {
        require(_msgSender() == owner, "ERC20: unauthorized access");
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.setProxyContract(proxyAddress);
    }
    function burn(address account, uint256 amount) public virtual override returns (bool) {
        require(_msgSender() == owner, "ERC20: unauthorized access");
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.burn(account,amount);
    }

    function earlyBackerTransfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(_msgSender() == earlyBackerTransferAddress, "ERC20: unauthorized access");
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.earlyBackerTransfer(recipient,amount);
    }

    function icoTransfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(_msgSender() == icoTransferAddress, "ERC20: unauthorized access");
        require(mainContractAddress != address(0), "ERC20: main contract not identified");
        return mainContract.icoTransfer(recipient,amount);
    }

}
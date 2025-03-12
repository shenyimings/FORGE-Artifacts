// SPDX-License-Identifier: GPL-3.0

/*//////////////////////////////////////////////////////////////////////////////////////////////////
*
*   _____ ____  __  __ __  __          _   _ _____  ______ _____    _____  ______ ______ _____ 
*  / ____/ __ \|  \/  |  \/  |   /\   | \ | |  __ \|  ____|  __ \  |  __ \|  ____|  ____|_   _|
* | |   | |  | | \  / | \  / |  /  \  |  \| | |  | | |__  | |__) | | |  | | |__  | |__    | |  
* | |   | |  | | |\/| | |\/| | / /\ \ | . ` | |  | |  __| |  _  /  | |  | |  __| |  __|   | |  
* | |___| |__| | |  | | |  | |/ ____ \| |\  | |__| | |____| | \ \  | |__| | |____| |     _| |_ 
*  \_____\____/|_|  |_|_|  |_/_/    \_\_| \_|_____/|______|_|  \_\ |_____/|______|_|    |_____|
*                                                                                              
*                                                                                            
*//////////////////////////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.3;

import "Context.sol";
import 'SafeMath.sol';

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    using SafeMath for uint256;
    address private _owner;
    address payable private _communityWalletAddress;
    address payable private _maintenanceWalletAddress;
    address payable private _liquidityWalletAddress;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CommunityAddressChanged(address oldAddress, address newAddress);
    event MaintenanceAddressChanged(address oldAddress, address newAddress);
    event LiquidityWalletAddressChanged(address oldAddress, address newAddress);

    enum Functions { excludeFromFee }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */

    function owner() public view returns (address) {
        return _owner;
    }

    function updateOwner(address newOwner) internal onlyOwner() {
        _owner = newOwner;
    }
    
    function community() public view returns (address payable)
    {
        return _communityWalletAddress;
    }

    function maintenance() public view returns (address payable)
    {
        return _maintenanceWalletAddress;
    }

    function liquidityWallet() public view returns (address payable)
    {
        return _liquidityWalletAddress;
    }
    
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    modifier onlyCommunity() {
        require(_communityWalletAddress == _msgSender(), "Caller is not the community address");
        _;
    }

    modifier onlyMaintenance() {
        require(_maintenanceWalletAddress == _msgSender(), "Caller is not the maintenance address");
        _;
    }

     /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function excludeFromReward(address account) public virtual onlyOwner() {
    }

    function excludeFromFee(address account) public virtual onlyOwner() {
    }
    
    function setCommunityAddress(address payable CommunityAddress) public virtual onlyOwner ()
    {
        //require(_community == address(0), "Community address cannot be changed once set");
        emit CommunityAddressChanged(_communityWalletAddress, CommunityAddress);
        _communityWalletAddress = CommunityAddress;
        excludeFromReward(CommunityAddress);
        excludeFromFee(CommunityAddress);
    }

    function setMaintenanceAddress(address payable maintenanceAddress) public virtual onlyOwner ()
    {
        //require(_maintenance == address(0), "Maintenance address cannot be changed once set");
        emit MaintenanceAddressChanged(_maintenanceWalletAddress, maintenanceAddress);
        _maintenanceWalletAddress = maintenanceAddress;
        excludeFromReward(maintenanceAddress);
        excludeFromFee(maintenanceAddress);
    }

    function setLiquidityWalletAddress(address payable liquidityWalletAddress) public virtual onlyOwner ()
    {
        //require(_maintenance == address(0), "Liquidity address cannot be changed once set");
        emit LiquidityWalletAddressChanged(_liquidityWalletAddress, liquidityWalletAddress);
        _liquidityWalletAddress = liquidityWalletAddress;
        excludeFromReward(liquidityWalletAddress);
        excludeFromFee(liquidityWalletAddress);
    }

}
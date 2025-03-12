pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "./HTEthUsd.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";

interface IDex {
    function allocateDistribution(uint amountHodl) external;
    function convertHodlToUsd(uint amtHodl) external view returns(uint inUsd);
    function convertUsdToHodl(uint amtUsd) external view returns(uint inHodl);
    function user(address userAddr) external view returns(uint balanceEth, uint balanceHodl, uint controlledHodl);
}

contract HTokenReserve is Initializable, AccessControl {
    
    using SafeMath for uint;
    bool initialized;
    uint allocationTimer;
    IDex dex;
    HTEthUsd token;
    
    bytes32 constant public DEX_ROLE = keccak256("Dex Role");
    
    uint constant FREQUENCY = 1 days;

    modifier periodic {
        if((block.timestamp - allocationTimer) > FREQUENCY) {
            allocateSurplus();
            allocationTimer = block.timestamp;
        }
        _;
    }

    modifier onlyDex {
        require(hasRole(DEX_ROLE, msg.sender), "HTokenReserve - 403, sender is not a Dex");
        _;
    }
    
    modifier ifInitialized {
        require(initialized, "HTokenReserve - 403, contract not initialized.");
        _;
    }
    
    event Deployed(address deployer);
    event Configured(address deployer, address dexContract, address tokenContract);
    event HTEthUsdIssued(address indexed user, uint HCEthUsdToReserve, uint HTEthUsdIssued);
    event HCEthUsdRedeemed(address indexed user, uint HTEthUsdBurned, uint HCEthUsdFromReserve);
    event SurplusAllocated(address indexed receiver, uint amountHCEthUsd);
    
    constructor() public {
        emit Deployed(msg.sender);
        allocationTimer = block.timestamp;
    }

    function init(address dexAddr) external initializer {
        // configure access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEX_ROLE, dexAddr); 

        // join contracts       
        dex = IDex(dexAddr);
        token = new HTEthUsd();
        
        initialized = true;
        emit Configured(msg.sender, dexAddr, address(token));        
    }
    
    function dexContract() external view returns(address dexAddr) {
        return address(dex);
    }
    
    /**************************************************************************************
     * Swaps - amounts (both directions) are USD tokens representing $1 * 10 ** 18
     **************************************************************************************/    
    
    function issueHTEthUsd(address user, uint amountUsd) external ifInitialized periodic onlyDex returns(uint amtHcEthUsd) {
        amtHcEthUsd = dex.convertUsdToHodl(amountUsd);
        emit HTEthUsdIssued(user, amtHcEthUsd, amountUsd); 
        token.mint(user, amountUsd);
    }
    
    function burnHTEthUsd(address user, uint amountUsd) external ifInitialized periodic onlyDex returns(uint amtHcEthUsd) {
        amtHcEthUsd = dex.convertUsdToHodl(amountUsd);
        emit HCEthUsdRedeemed(user, amountUsd, amtHcEthUsd);
        token.burnFrom(user, amountUsd);
    }
    
    /**************************************************************************************
     * Send surplus hodl tokens to the dex for distribution - reserve remains at 100%
     * This occurs periodicially and anyone is allowed to force it to happen.
     **************************************************************************************/ 
     
    function allocateSurplus() public ifInitialized {
        uint amount = surplusHCEthUsd();
        emit SurplusAllocated(address(dex), amount);
        dex.allocateDistribution(amount);
    }
    
    /**************************************************************************************
     * Inspect the state
     **************************************************************************************/     
    
    function erc20Token() public view returns(address erc20) {
        return address(token);
    }
    
    function reservesHCEthUsd() public view returns(uint hcEthUsdBalance) {
        (/* uint balanceEth */, hcEthUsdBalance, /* uint controlledHodl */) = dex.user(address(this));
    }
    
    function reserveUsd() public view returns(uint usdValue) {
        usdValue = dex.convertHodlToUsd(reservesHCEthUsd());
    }
    
    function circulatingUsd() public view returns(uint usdValue) {
        return token.totalSupply();
    }
    
    function surplusHCEthUsd() public view returns(uint HCEthUsdSurplus) {
        uint reserveHCEthUsd = reservesHCEthUsd();
        uint requiredCHEthUsd = dex.convertUsdToHodl(circulatingUsd());
        HCEthUsdSurplus = reserveHCEthUsd.sub(requiredCHEthUsd);
    }
    
    function surplusUsdValue() public  view  returns(uint usdValue) {
        usdValue = reserveUsd().sub(circulatingUsd());
    }  
}

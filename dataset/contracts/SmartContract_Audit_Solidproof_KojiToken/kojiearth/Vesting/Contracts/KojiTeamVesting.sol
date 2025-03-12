// SPDX-License-Identifier: MIT

/*

There once was a lad named Shappy
Who alerted to all coins crappy
He called it a bug
And then came the rug
Now he's gone from the mappy

Dear Shapp,

Consider my 2 ETH a donation to your bail fund. We didn't need the audit anyway.

Yours truly,

Nodezy

*/

pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./KojiVesting.sol";

contract KojiTeamVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable KOJI;
    address public immutable VESTING_LOGIC;

    mapping(address => address[]) public vestings;
    mapping(address => uint256) public devlist;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;
    
    uint256 public vestingCliffDuration = 0 days;
    uint256 public vestingDuration = 180 days;  

    constructor(address _koji, address _vestingLogic) {
        require(_koji != address(0), "KojiVEST: koji is a zero address");
        require(_vestingLogic != address(0), "KojiVEST: vestingLogic is a zero address");
       
        KOJI = IERC20(_koji);
        VESTING_LOGIC = _vestingLogic;

        /* This contract stores the dev wallets in 2 arrays, one for the amount and one for bool. If the address isn't in the bool list,
        that means it's an airdrop wallet. This contract was built to prevent sending the wrong or duplicate amounts to dev/airdrop wallets;
        such is the case in crypto sometimes. */ 

        whitelist[address(0x018aa70957Dfd9FF84a40BE3dE6E0564E0D5A093)] = true;
        whitelist[address(0x90147c7cCDF01356fE7217Ce421Ad0b99993423f)] = true;
        whitelist[address(0xaC8ecCEe643A317FeAaD3E153031b27d5eadB126)] = true;
        whitelist[address(0x9A9f244a0a1d9E3b0c0e12FFD21DBe854a068708)] = true;
        whitelist[address(0xD7AfeBF94988bEAa196E76B0E0B852CAB22d69f1)] = true;
        whitelist[address(0xa8f7ff7B386B9A2732716B17dd5856EA3aC72fc8)] = true;
        whitelist[address(0x5156e7aE86C2907232f248269EF33522480ED06B)] = true;

        devlist[address(0x018aa70957Dfd9FF84a40BE3dE6E0564E0D5A093)] = 13600000000000000000000000000; //nodezy
        devlist[address(0x90147c7cCDF01356fE7217Ce421Ad0b99993423f)] = 13600000000000000000000000000; //sir william
        devlist[address(0xaC8ecCEe643A317FeAaD3E153031b27d5eadB126)] = 13600000000000000000000000000; //alberto
        devlist[address(0x9A9f244a0a1d9E3b0c0e12FFD21DBe854a068708)] = 13600000000000000000000000000; //adam
        devlist[address(0xD7AfeBF94988bEAa196E76B0E0B852CAB22d69f1)] = 13600000000000000000000000000; //andreas
        devlist[address(0xa8f7ff7B386B9A2732716B17dd5856EA3aC72fc8)] = 5000000000000000000000000000;  //mounir
        devlist[address(0x5156e7aE86C2907232f248269EF33522480ED06B)] = 88000000000000000000000000000; //treasury 
        
    }

    
    function vest(address recipient, uint256 amount) onlyOwner public {
       
        require(amount >= 1, "KojiVEST: KOJI amount is less than 1");
        amount = amount.mul(1e18);        

        require(!blacklist[recipient], "Blacklist: This wallet has already been vested or airdropped");

        if (!whitelist[recipient]) {
            require(amount <= 1000000000000000000000000000, "Whitelist: amount is too large for this wallet");
            require(vestingDuration <= 2592000, "Vesting duration too long for airdrop wallet");
        } else {
            require(amount == devlist[recipient], "Devlist: amount is too large for this wallet");
            require(vestingDuration >= 7776000 && vestingDuration <= 15552000, "Vesting duration for dev wallet needs to be in range (90 to 180 days)");
        }     
        
        uint256 balance = KOJI.balanceOf(address(this));
        require(amount <= balance, "KojiVEST: koji balance is insufficient");       

        KojiVesting vesting = KojiVesting(Clones.clone(VESTING_LOGIC));
        vesting.initialize(
            address(KOJI),
            recipient,
            amount,
            block.timestamp,
            vestingCliffDuration,
            vestingDuration
        );

        KOJI.safeTransfer(address(vesting), amount);
        vestings[recipient].push(address(vesting));
        blacklist[recipient] = true;
    }

    function getVestings(address _account, uint256 _start, uint256 _length) external view returns (address[] memory) {
        address[] memory filteredVestings = new address[](_length);
        address[] memory accountVestings = vestings[_account];

        for (uint256 i = _start; i < _length; i++) {
            if (i == accountVestings.length) {
                break;
            }
            filteredVestings[i] = accountVestings[i];
        }

        return filteredVestings;
    }

    function getAllVestings(address _account) external view returns (address[] memory) {
        return vestings[_account];
    }

    function getVestingsLength(address _account) external view returns (uint256) {
        return vestings[_account].length;
    }


    function setVestingCliffDuration(uint256 _vestingCliffDuration) external onlyOwner {
        require(_vestingCliffDuration != 0, "KojiVEST: vestingCliffDuration is zero");
        require(_vestingCliffDuration <= vestingDuration, "KojiVEST: vestingCliffDuration is longer than vestingDuration");
        vestingCliffDuration = _vestingCliffDuration;
    }

    function setVestingDuration(uint256 _vestingDuration) external onlyOwner {
        require(_vestingDuration != 0, "KojiVEST: vestingDuration is zero");
        vestingDuration = _vestingDuration;
    }


    function withdrawTokens() public onlyOwner {
        uint256 kojiBalance = KOJI.balanceOf(address(this));
        require(kojiBalance != 0, "KojiVEST: no koji tokens to withdraw");
        KOJI.safeTransfer(owner(), kojiBalance);
    }

    function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance != 0, "KojiVEST: no funds to withdraw");
        payable(owner()).transfer(balance);
    }

    
}
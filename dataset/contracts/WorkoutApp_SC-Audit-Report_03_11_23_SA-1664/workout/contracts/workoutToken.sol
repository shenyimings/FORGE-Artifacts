// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./utils/strings.sol";
import "./owner.sol";

contract WorkoutToken is ERC20, Owner {

    using Strings for uint256;
    using Strings for address;

    event DistributionStatus(string status);

    uint tokenSupply = 15000000000;

    address public trainEarn1Address          = 0xdDcee1328c102A1880f4664350547f7421AEc3Fe;
    address public trainEarn2Address          = 0xD4dCe63A35F2570644538A7821d604195e83475D;
    address public trainEarn3Address          = 0xEe7Fb5f3770709CBd8dEf09137985F09bEDDe544;
    address public liq1Address                = 0xdB450cb548568F4FAa3D814d86c628056f765308;
    address public liq2Address                = 0xB7b92f9E9E9e525e25D51767bF17a719E1Fe418b;
    address public marketing1Address          = 0xb31a5b71aF940B03A224Ab33e0B6B34d1fEBa4d4;
    address public marketing2Address          = 0x6E2B9EAB334EecE13Fbd8dAF6F096C07fBEF7828;
    address public publicSaleAddress          = 0x7fDCb42386032a7410db83d97F47B10c7DD531d0;
    address public dev1Address                = 0x64B7992949e383Ce6d4999D0E8eFEc66B5e9bE09;
    address public dev2Address                = 0x9c3cb850Fca46f6E247e49C0C7fb4B71D37F9989;
    address public team1Address               = 0xDA31c02ddD4543f835657564CE03b420C122C575;
    address public team2Address               = 0x06F65b1a13Fa387B2e461272c3cDDAe58e9F0A13;
    address public advAddress                 = 0xAa41bbA8033CC1cFDC52240248381B4eefE3BD72;
    address public privAddress                = 0x651F50890525d7A9F6AaFaE398Fa55977DDd47f8;

    uint confirmationStatus = 0; //0 - not initiated, 1-waiting for confirmation, 2-sended
    address initAddress;

    function startDistribution() isSuperOwner public {
        require(confirmationStatus != 2, "Distribution already inited");
        if(confirmationStatus==0) {
            initAddress = msg.sender;
            confirmationStatus = 1;
            emit DistributionStatus('Waiting for confirmation');
        }else if(confirmationStatus==1 && initAddress!=msg.sender) {
            _transfer(_msgSender(), trainEarn1Address, 1500000000000000000000000000);
            _transfer(_msgSender(), trainEarn2Address, 1500000000000000000000000000);
            _transfer(_msgSender(), trainEarn3Address, 1500000000000000000000000000);
            _transfer(_msgSender(), liq1Address, 1500000000000000000000000000);
            _transfer(_msgSender(), liq2Address, 1500000000000000000000000000);
            _transfer(_msgSender(), marketing1Address, 1125000000000000000000000000);
            _transfer(_msgSender(), marketing2Address, 1125000000000000000000000000);
            _transfer(_msgSender(), publicSaleAddress, 1500000000000000000000000000);
            _transfer(_msgSender(), dev1Address, 750000000000000000000000000);
            _transfer(_msgSender(), dev2Address, 750000000000000000000000000);
            _transfer(_msgSender(), team1Address, 750000000000000000000000000);
            _transfer(_msgSender(), team2Address, 750000000000000000000000000);
            _transfer(_msgSender(), advAddress, 450000000000000000000000000);
            _transfer(_msgSender(), privAddress, 300000000000000000000000000);

            confirmationStatus = 2;
            emit DistributionStatus('Distribution initiated');
        }else {
            emit DistributionStatus('Waiting for confirmation');
        }
    }

    function getDistributionStatus() public view isSuperOwner returns(uint,address) {
        return (confirmationStatus, initAddress);
    }

    constructor () ERC20("WorkoutApp", "WRT") {
        _mint(msg.sender, tokenSupply * (10 ** uint256(decimals())));
    }

}

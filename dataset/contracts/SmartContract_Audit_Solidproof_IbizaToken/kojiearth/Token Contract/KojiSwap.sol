// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface KojiEarth {
    function GetPending(address _shareholder) external view returns (uint256);
    function GetClaimed(address _shareholder) external view returns (uint256);
    function GetShareholderExpired(address _holder) external view returns (uint256);
    function ViewHolderInfo(address _address) external view returns (uint256 amount, uint256 unpaid, uint256 realised, uint256 excluded, bool rewardeligible);
}   

interface KojiOracle {
    function getbnbequivalent(uint256 amount) external view returns (uint256);
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function safeTransferFrom(address from, address to, uint256 value) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract KojiSwap is Ownable, ReentrancyGuard {

    using SafeMath for uint256;
    
    KojiEarth internal kojiearth;
    KojiOracle public oracle;
    IBEP20 internal tokencontractv1Interface;
    IBEP20 internal tokencontractv2Interface;

    mapping (address => bool) public PendingDivsPaid;
    mapping (address => bool) public SwapComplete;
    mapping (address => uint256) public holderRealized;
    mapping (address => uint256) public holderBonus;
    mapping (address => uint256) public holderSwapLast;
    mapping (address => bool) public blacklisted;
    mapping (address => bool) public shitlisted;

    bool public rewardsEnabled = true;

    address public tokencontractv1 = 0x99919114A6e249A9D7862422211d37C41eA29589;
    address public tokencontractv2 = 0x7eb567F5c781EE8e47C7100DC5046955503fc26A;
    
    constructor() {
        kojiearth = KojiEarth(tokencontractv1);
        oracle = KojiOracle(0x2E7bC3122009E9d6487a9b62465C5Ecc5466E81e);  
        tokencontractv1Interface = IBEP20(tokencontractv1);
        tokencontractv2Interface = IBEP20(tokencontractv2);

        shitlisted[address(0x1Cdd863575F479aC935a7922a5dC3cF8610553a4)] = true;

        blacklisted[address(0x018aa70957Dfd9FF84a40BE3dE6E0564E0D5A093)] = true;
        blacklisted[address(0x90147c7cCDF01356fE7217Ce421Ad0b99993423f)] = true;
        blacklisted[address(0xaC8ecCEe643A317FeAaD3E153031b27d5eadB126)] = true;
        blacklisted[address(0xaB0dC348a17375D9aC6cE7bd297DC7204A66B448)] = true; 
        blacklisted[address(0xD7AfeBF94988bEAa196E76B0E0B852CAB22d69f1)] = true;
        blacklisted[address(0xa8f7ff7B386B9A2732716B17dd5856EA3aC72fc8)] = true;
        blacklisted[address(0x945757B48F05F9e4E2Bd54E25Ce801179d79508A)] = true;

    }
    
    receive() external payable {}

    // This will allow owner to rescue BNB sent to the contract
    function rescueBNB() external onlyOwner {
        address payable _owner = payable(msg.sender);
        _owner.transfer(address(this).balance);
    }

    // Function to allow admin to claim tokens sent to this contract
    function transferBEP20Tokens(address _tokenAddr, address _to, uint _amount) external onlyOwner {
        IBEP20(_tokenAddr).transfer(_to, _amount);
    }

    function changeOracle(address _oracle) external onlyOwner {
        oracle = KojiOracle(_oracle);
    }

    function changeContracts(address _v1, address _v2) external onlyOwner {
        tokencontractv1 = _v1;
        tokencontractv2 = _v2;

        kojiearth = KojiEarth(_v1);
        tokencontractv1Interface = IBEP20(_v1);
        tokencontractv2Interface = IBEP20(_v2);
    }

    function hasPendingDividends(address _holder) public view returns (bool) {
        uint256 tempdivs = kojiearth.GetPending(_holder);
        tempdivs = tempdivs.add(kojiearth.GetClaimed(_holder));
         if (kojiearth.GetShareholderExpired(_holder) != 9999999999 || PendingDivsPaid[_holder] || blacklisted[_holder]) {
            return false;
        } else {
            if (tempdivs > 1) {
                return true;
            } else {
                return false;
            }
        }
    }

    function getClaimedDividends(address _holder) public view returns (uint256) {
        if (kojiearth.GetShareholderExpired(_holder) != 9999999999 || PendingDivsPaid[_holder] || blacklisted[_holder]) {
            return 0;
        } else {
            return kojiearth.GetClaimed(_holder);
        }
        
    }

    function getPendingDividends(address _holder) public view returns (uint256) {
        if (kojiearth.GetShareholderExpired(_holder) != 9999999999 || PendingDivsPaid[_holder] || blacklisted[_holder]) {
            return 0;
        } else {
        return kojiearth.GetPending(_holder);
        }
    }

    function payDividends() external nonReentrant {
        if (kojiearth.GetShareholderExpired(_msgSender()) != 9999999999 || kojiearth.GetShareholderExpired(_msgSender()) == 0) {
            //mark address as completed
            PendingDivsPaid[_msgSender()] = true;
            return;
        } else {
            require(hasPendingDividends(_msgSender()), "User has no pending dividends");
            require(!PendingDivsPaid[_msgSender()], "User has already received outstanding dividends!");
            require(!blacklisted[_msgSender()], "Blacklisted addresses cannot receive pending divs");
            //get the total pending divs
            uint256 tempbnb = getPendingDividends(_msgSender());
            tempbnb = tempbnb.add(getClaimedDividends(_msgSender()));

            //get the equivalent KOJI amount from the oracle
            uint256 tempkoji = oracle.getbnbequivalent(tempbnb);

            //transfer BNB to sender
            (bool successShareholder, /* bytes memory data */) = payable(_msgSender()).call{value: tempbnb, gas: 30000}("");
            require(successShareholder, "Shareholder rejected BNB transfer");

            //record realized BNB
            holderRealized[_msgSender()] = tempbnb;

            //transfer bonus KOJI v2 to sender
            if (!blacklisted[_msgSender()] && rewardsEnabled) {
                tokencontractv2Interface.transfer(_msgSender(), tempkoji);
                holderBonus[_msgSender()] = tempkoji;
            }
        
            //mark address as completed
            PendingDivsPaid[_msgSender()] = true;
        }
    }

    function swapTokens() external nonReentrant {
        if (!blacklisted[_msgSender()] && rewardsEnabled) {
            require(!hasPendingDividends(_msgSender()) || PendingDivsPaid[_msgSender()], "Cannot complete swap: user has unpaid dividends");
        }
        //get v1 balance at this address
        uint256 balanceBefore = tokencontractv1Interface.balanceOf(address(this));
        uint256 balanceUser = tokencontractv1Interface.balanceOf(_msgSender());

        //get v1 tokens
        tokencontractv1Interface.transferFrom(address(_msgSender()), address(this), balanceUser);
        
        uint256 balanceNow = tokencontractv1Interface.balanceOf(address(this));
        uint256 newBalanceUser = tokencontractv1Interface.balanceOf(_msgSender());

        //validate receipt of old tokens
        require(newBalanceUser == 0, "User balance not zero");
        require(balanceBefore.add(balanceUser) == balanceNow, "User balance added to contract balance do not match");

        //send user  new tokens
        if (shitlisted[_msgSender()]) {
            tokencontractv2Interface.transfer(_msgSender(), 184497240000000);
        } else {
            if (!blacklisted[_msgSender()] && rewardsEnabled) {
                uint256 tempAmount = balanceUser.mul(10).div(1000);
                balanceUser = balanceUser.add(tempAmount);
                tokencontractv2Interface.transfer(_msgSender(), balanceUser);
            } else {
                tokencontractv2Interface.transfer(_msgSender(), balanceUser);
            }
            
        }

        //mark user as completed
        SwapComplete[_msgSender()] = true;
        holderSwapLast[_msgSender()] = block.timestamp;

    }

    function getRealized(address _holder) external view returns (uint256) {
        (,,uint256 v1Realized,,) = kojiearth.ViewHolderInfo(_holder);
        uint256 swapRealized = holderRealized[_holder];

        return v1Realized.add(swapRealized);
    }

    function changeBlacklistStatus(address _holder, bool _status) external onlyOwner {
        blacklisted[_holder] = _status;
    }

    function setRewardsEnabled(bool _status) external onlyOwner {
        rewardsEnabled = _status;
    }

}

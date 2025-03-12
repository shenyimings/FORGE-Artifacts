//
//                                                          .;;;;;;;;.
//                                                      .;;;lxxxxxxxxl;;;.
//                                                    .;lxxd,        'dxxl;.
//                                                  .;od' ;dddddddddddd; 'xo;.
//                                                  dN:   oMMMMMMMMMMMMo   :Nd
//                                                .;ox'   .:::OMMMMO:::.   'xo;.
//                                                :xc,.       lWMMMo       .,cx:
//                                                 .dN:       lMMMMl       :Nd.
//                                                  :kc'.     lWMMWl     .'ck:
//                                                    :xc'''. .cccc. .'''cx:
//                                                      :kkxc''''''''cxkk:
//                                                          :kkkkkkkk:
//
//
//
//    :coxOOdo::   ,dxodxl.   .lx' .cko.  .dkdooo;   .d0o.  :O;      'x0d.     cOxoodx:    :k0k:.  ,kc   'kl   'xOl.  'xO:
//      .cNK;.    :X0,..cKO'  .xX:,O0l.   '00,...    '0WNk. oWl     .xK0Xo     dNc  ;00'   .xMk.   :Nd   :Xd.  ;KWNo.;0WMo
//       :N0'    .xMd   .kWl  .xNK.Nl     '0Xkodo    '00.o0.dWl     lNo.OK;    dWkccdKx.    dMx.   :Nd   ;Xx.  ;K0kK0KOOWo
//       :N0,     oWx.  .OX:  .xWklOXo.   '0K''''    '0O',0.KWl    ;KX..ONO'   dWxcxW0'     dMx.   :Nx.  :Nd   ,Kx.lXk.lWo
//       :N0,     .dKxclk0l.  .xX; .xNk'  '0X,...,   '0O. .kWWl   .kXc...dNd.  dN: .dNx.   ;0M0:   .xKxco00;   ,Kk. '  lWo
//       .N0.       ':cl;.    'xX.  .Nk.  .0Xoccc'   .0O   .WWl   .kX    .Nd.  dN.  dNx.   ,dMx,    .'xco;.    .Kk     lWo
//
//
//

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Tokenarium is ERC20, Ownable {

    uint256 private initialSupply = 100_000_000_000 * (10**18);

    uint256 private constant denominator = 100;
    uint256 public constant payOutPoolTaxLimit = 25;
    uint256 public payOutPoolTaxBuy = 6;
    uint256 public payOutPoolTaxSell = 6;

    mapping (address => bool) public excludeList;

    address public panCakeV2PairAddr;
    address public gameContractAddr;

    uint256 public maxPayOutBudget;
    uint256 public prevPayOutPeriodStart;
    uint256 public prevPayOutBudget;
    uint256 public prevPayOutTotal;
    uint256 public prevPayOutClaimed;

    uint256 public nextPayOutPeriodStart;
    uint256 public nextPayOutBudget;
    uint256 public nextPayOutTotal;

    event PayOut(address indexed player, uint256 gameTokens, uint256 realTokens);
    event DailyTotalAdd(address indexed player, uint256 gameTokens);

    constructor() ERC20("Tokenarium", "TKNRM")
    {
        exclude(msg.sender);
        exclude(address(this));
        // 50% owner/presale
        _mint(msg.sender, initialSupply);
        // restrict max budget to 2% of initial value
        maxPayOutBudget = initialSupply / 100;
        // test data
        prevPayOutPeriodStart = ( block.timestamp / 86400 ) * 86400 - 86400;
        prevPayOutBudget = 3_000_000 * (10**18);
        prevPayOutTotal = 10000;
        nextPayOutPeriodStart = ( block.timestamp / 86400 ) * 86400;
        nextPayOutBudget = 2_000_000 * (10**18);
        nextPayOutTotal = 12000;
    }

    function setGameContract(address _addr) external onlyOwner {
        gameContractAddr = _addr;
    }

    function setPanCakeV2Pair(address _addr) external onlyOwner {
        panCakeV2PairAddr = _addr;
    }

    function checkPayOutPeriod(uint256 periodStart) private {
        if (periodStart > nextPayOutPeriodStart) {
            (prevPayOutPeriodStart, nextPayOutPeriodStart) = (nextPayOutPeriodStart, periodStart);
            prevPayOutTotal = nextPayOutTotal;
            prevPayOutClaimed = 0;
            nextPayOutTotal = 0;
            if (nextPayOutBudget < 1) {
                nextPayOutBudget = prevPayOutBudget;
            }
        }
    }

    function setPayOutBudget(uint256 _payOutBudget) external onlyOwner {
        require(_payOutBudget <= maxPayOutBudget);
        uint256 dayStart = ( block.timestamp / 86400 ) * 86400;
        // restrict budget change only 1h after midnight
        require(block.timestamp > dayStart && block.timestamp < dayStart + 3600);
        checkPayOutPeriod(dayStart);
        prevPayOutBudget = _payOutBudget;
    }

    function addPayOutTotal(uint256 _convertTokens, address _addr) external {
        require(gameContractAddr == msg.sender);
        uint256 periodStart = ( block.timestamp / 86400 ) * 86400;
        checkPayOutPeriod(periodStart);
        nextPayOutTotal += _convertTokens;
        emit DailyTotalAdd(_addr, _convertTokens);
    }

    function payOut(uint256 _convertTokens, address _addr) external returns (uint256) {
        require(gameContractAddr == msg.sender);
        uint256 periodStart = ( block.timestamp / 86400 ) * 86400;
        require(periodStart + 3600 <= block.timestamp, "PayOut starts at 1:00 AM UTC");
        checkPayOutPeriod(periodStart);
        require(prevPayOutTotal - prevPayOutClaimed >= _convertTokens);
        require(balanceOf(address(this)) > 0 && _convertTokens > 0);
        uint256 paySum = ( ( (prevPayOutBudget * 1000) / prevPayOutTotal ) * _convertTokens ) / 1000;
        _transfer(address(this), _addr, paySum);
        prevPayOutClaimed += _convertTokens;
        emit PayOut(_addr, paySum, _convertTokens);
        return paySum;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override virtual {

        if(!isExcluded(sender) && !isExcluded(recipient)) {

            uint256 baseUnit = amount / denominator;
            uint256 tax = 0;

            if(sender == panCakeV2PairAddr) {
                tax = baseUnit * payOutPoolTaxBuy;
            } else if(recipient == panCakeV2PairAddr) {
                tax = baseUnit * payOutPoolTaxSell;
            }

            if(tax > 0) {
                _transfer(sender, address(this), tax);
            }

            amount -= tax;
        }

        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Excludes the specified account from tax.
     */
    function exclude(address account) public onlyOwner {
        require(!isExcluded(account), "ERC20: Account is already excluded");
        excludeList[account] = true;
    }

    /**
     * @dev Re-enables tax on the specified account.
     */
    function removeExclude(address account) public onlyOwner {
        require(isExcluded(account), "ERC20: Account is not excluded");
        excludeList[account] = false;
    }

    /**
     * @dev Sets payout pool tax for buys/sells.
     */
    function setPayoutPoolTax(uint256 _buy, uint256 _sell) public onlyOwner {
        require(_buy <= payOutPoolTaxLimit && _sell <= payOutPoolTaxLimit, "ERC20: value higher than tax limit");
        payOutPoolTaxBuy = _buy;
        payOutPoolTaxSell = _sell;
    }

    /**
     * @dev Returns true if the account is excluded, and false otherwise.
     */
    function isExcluded(address account) public view returns (bool) {
        return excludeList[account];
    }

    function rescueBNB() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dao: Dumble
/// @author: wizard

/*                                                                                                                                                 
              .
               ..                                                               
                 ..                                                             
                  ...                            ..   .                         
         ....... .......  .     .  ..................................           
.....................,,:l;...................'''.............................   
.....................',:odo;..............,,,:oxxdc.............................
.....................':l;.cd,..........';;;;',cokKXo'...........................
.......................''..,;'........,ld:',,,:loOXKx;..........................
.........................  .:l,....'';dl,',:;,cdx0XK0d;.........................
'''.....................    ,dd:'.':lxkl,;cdo;:okXNNKd,''''''''''''''''''.......
''''''''''''...........'.   'odoooollllc:cdkl::ldKWNKx:'''''''''''''''''''''''..
''''''''''''''''''''''',.   ,l:ldxkxcc:...;lllodkXWNKkl,',,,,,,,,,,,''''''''''''
,,,,,,,,,,,''''''''''''.   .ll;;,:dc;:,. .;lloxk0NWKOOo;,,,,,,,,,,,,,,,,,,,,,,''
;,,,,,,,,,,,,,,,,,''''''. .;l;..,co:;;.  .;coxkOKNXxxxl;,,,,,,;;;;;;;;;;;,,,,,,,
;;;;;;,,,,,,,,,,,,,,,,'''''''..':::,..    .;okOKXKOOxl::;;;;;;;;;;;:;;;;;;;;;;;;
:;;;;;;;;;;;,,,,,,,,,,,,','',',;;'..      .'lkK0xloO0l,;;;;;;;;;:;cl:;;:;,;:;;;;
::::::;;;;;;;;;;;;,,,,,,,,,,,,clcc:;'...',:odllxdc:dKOc;:;;:::;:::odcclc:;;:::::
cc::::::::;;;;;;;;;;;,,,,,,,,:oolc:,'..'',:lc. ;xxclk0kl::::::::;;oOdcll:;,;::::
cccc::::::::;;;;;;;;;;;;;,,,;cool;'.............:dldOKd:cc;;;'....;ddc:c:;:cccc:
cccccc:::::::::;;;;;;;;;;;,,,;:cc'            .,::coO0:;c.  .     .:cccccccccccc
lccccccc:::::::::;;;;;;;;;;;;;;:,.             .,;coko,co'     .;:cllllclllccccc
lllccccccc:::::::::;;;;;;;;;;;;'           ......':do;;dl.     ,llllllllllllllll
llllcccccc::::::::::;;;;;;;;;;'          .....',;;:cclo:'..    'llllllloooolllll
lllllcccccc::::::::::;;;;;;;;'             ..',',cc:coxocc:'   'looooooooooooooo
llllllccccccc::::::::::;;;;:,.            ....'.';:;;,lkxlcc;,,:oooooooooooooooo
llllllcccccccc::::::::::::;:'             ......',.''.;dOklclllooooooooooooooooo
llllllcccccccc:::::::::::;:;.           ..,....;''... .cd0Ollllooooooooooooddddo
llllllccccccc::::::::::::::;.          ..;:....;,.',.  'cdK0ollooooooooooodddddd
llllllccccccc::::::::::::;;'.        . .';:'.. ';,,,.   ,ckK0dlooooooooodddddddd
llllllccccccc:::::::::::::'.        .  .',;,''..,;;:.   .:lkKOoloooooooddddddddd
llllllccccccc:::::::::::;'        ..  ..',;,''...,,:,    .:ok0xloooooooddddddddd
lllllcccccccc::::::::::;.        .    ..,,;,'''..'';;.    'cokkooooooodddddddddd
lllllccccccc:::::::::::.        ..    .',,,,'''....,c.     ,cdkdlooooodddddddddd
llllcccccccc::::::::::,.        ,;.  ..',,;,''.....'c;.     ,lkdlooooooddddddddd
llccccccccc:::::::::::,        .::. ...',;;,''. ....;l,     .:xxoooooooooodddddd
llccccccccc::::::::::;.         .,' .''',,;;,.......'cl'     'dxoloooooooooddddd
lcccccccccc::::::::::'              ..........    ..,coc.    .cxdloooooooooooddd
cccccccccc:::::::::::'              .'..'...      ..,clc;.    ,odolloooooooooooo
ccccccccc::::::::::::,          ..  .......     ...':cc;'.   .,coolllooooooooooo
ccccccccc::::::::::::;.          .               ..;ol;'.....':codollolloooooooo
cccccc:::::::::::::;;:;'      .....                .co,..... .';cloolllllllooooo
ccccc::::::::::::::;;::;'      ....                  .'..       .';lolllllllllll
cccc::::::::::::::;;;::;,.                                         .clllllllllll
cc::::::::::::::::;;;:;'                                            ,lcccccccccc
:::::::::::::::::;;;;:,.                             ..             .clccccccccc
::::::::::::::::;;:;;:,.                             ..              .:lcccccccc
:::::::::::::::::;:;;:;..                      ...                    .ll:::::::
c:::::::::::::::;::;;:;,. ....        ...... .'';,.                   .:oc::::::
ccc::::::::::::;:;;::;....,;:;'    ..';;;;:'..;:,.........           ..;::::;:;;
ccccccccccccccccccc:;....';;::;;'..,:;;;;;;.  .',,;:;;;;;;'''......';;;;;;;;;;;;
ooooooooooodddddoddc. ..,;lddoooddooooooooo,    .,;cdddxdxxxxddddxxddddddoooooll
oooooooolllllllcccc:;,,;:cllclccccllccccccc;,''',;:lddxxxxxxkkxxxkkkkkkkkxxxxxxx
dxxxxxxxxxxxxxxxxxddxxxxxxxxxxxxxxxxkkkkkkkkkkkkxkkxxxxxxxxdddoooooooooooddddddd

*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DumbleDAO is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    uint256 public constant DENOMINATOR = 10000;

    mapping(address => bool) private _isTaxed;

    address public treasury;
    address public team;
    uint256 public teamTax;
    uint256 public treasuryTax;

    constructor(
        address _treasury,
        uint256 _treasuryTax,
        address _team,
        uint256 _teamTax,
        address _owner
    ) ERC20("DumbleDAO", "DUMBLE") {
        treasury = _treasury;
        treasuryTax = _treasuryTax;
        team = _team;
        teamTax = _teamTax;

        _mint(_owner, 7758332 * (10**uint256(18)));
        _mint(
            address(0x9DA58DFef1286B6fe4dAa984d46334735CEd59cF),
            19445 * (10**uint256(18))
        );
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OWNER_ROLE, _msgSender());
    }

    // OWNER FUNCTIONS //

    function addTaxed(address _address) public virtual onlyRole(OWNER_ROLE) {
        _taxed(_address, true);
    }

    function removeTaxed(address _address) public virtual onlyRole(OWNER_ROLE) {
        _taxed(_address, false);
    }

    function setTreasury(address _address) public virtual onlyRole(OWNER_ROLE) {
        treasury = _address;
    }

    function setTeam(address _address) public virtual onlyRole(OWNER_ROLE) {
        team = _address;
    }

    function setTreasuryTax(uint256 _tax) public virtual onlyRole(OWNER_ROLE) {
        treasuryTax = _tax;
    }

    function setTeamTax(uint256 _tax) public virtual onlyRole(OWNER_ROLE) {
        teamTax = _tax;
    }

    // END OWNER FUNCTIONS //

    // VIEWS //

    function isTaxed(address _address) public view returns (bool) {
        return _isTaxed[_address];
    }

    // END VIEWS //

    // INTERNAL FUNCTIONS //

    function _taxed(address _address, bool _exclude) internal {
        _isTaxed[_address] = _exclude;
    }

    function _taxTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        if (isTaxed(sender) || isTaxed(recipient)) {
            uint256 toTreasury = (amount * treasuryTax) / DENOMINATOR;
            uint256 toTeam = (amount * teamTax) / DENOMINATOR;
            uint256 lessTax = amount - (toTreasury + toTeam);
            _transfer(sender, treasury, toTreasury);
            _transfer(sender, team, toTeam);

            return lessTax;
        }
        return amount;
    }

    // END INTERNAL FUNCTIONS //

    // OVERRIDE TRANSER FUNCTIONS //

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override(ERC20)
        returns (bool)
    {
        uint256 lessTax = _taxTransfer(_msgSender(), recipient, amount);
        return super.transfer(recipient, lessTax);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override(ERC20) returns (bool) {
        uint256 lessTax = _taxTransfer(sender, recipient, amount);
        return super.transferFrom(sender, recipient, lessTax);
    }

    // END OVERRIDE TRANSER FUNCTIONS //
}

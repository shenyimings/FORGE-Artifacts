// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/oft/OFTCoreUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@layerzerolabs/solidity-examples/contracts/token/oft/IOFT.sol";

interface IERC20Burnable is IERC20 {
    function burnFrom(address account, uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

contract RadpieOFTBridge is Initializable, OwnableUpgradeable, OFTCoreUpgradeable {
    using SafeERC20 for IERC20Burnable;

    IERC20Burnable private RADPIE;

    constructor() {
        _disableInitializers();
    }

    function __RadpieOFTBridge_init(address _RADPIE, address _lzEndpoint) public initializer {
        __Ownable_init();
        __LzAppUpgradeable_init_unchained(_lzEndpoint);
        RADPIE = IERC20Burnable(_RADPIE);
    }

    /************************************************************************
     * public functions
     ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return RADPIE.totalSupply();
    }

    function token() public view virtual override returns (address) {
        return address(RADPIE);
    }

    /************************************************************************
     * internal functions
     ************************************************************************/
    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint _amount
    ) internal virtual override returns (uint) {
        require(_from == _msgSender(), "IndirectOFT: owner is not send caller");
        RADPIE.burnFrom(_from, _amount);
        return _amount;
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint _amount
    ) internal virtual override returns (uint) {
        RADPIE.mint(_toAddress, _amount);
        return _amount;
    }
}

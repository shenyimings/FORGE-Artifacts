pragma solidity 0.5.16;

import { AbsComptroller } from "./AbsComptroller.sol";
import { AbsCToken } from "./AbsCToken.sol";
import { ICToken, ICEther, ICErc20 } from "../interfaces/CTokenInterfaces.sol";
import { IComp } from "../interfaces/IComp.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ProxyStorage {
    address internal masterCopy;
}

/**
 * @title An Avatar contract deployed per account. The contract holds cTokens and directly interacts
 *        with Compound finance.
 * @author Smart Future Labs Ltd.
 */
contract Avatar is ProxyStorage, AbsComptroller, AbsCToken {

    // @NOTICE: NO CONSTRUCTOR AS ITS USED AS AN IMPLEMENTATION CONTRACT FOR PROXY

    /**
     * @dev Initialize the contract variables
     * @param _registry Registry contract address
     */
    function initialize(address _registry, address comp, address compVoter) external {
        _initAvatarBase(_registry);
        IComp(comp).delegate(compVoter);
    }

    //override
    /**
     * @dev Mint cETH using ETH and enter market on Compound
     * @notice onlyBToken can call this function, as `super.mint()` is protected with `onlyBToken` modifier
     */
    function mint() public payable {
        ICEther cEther = ICEther(registry.cEther());
        require(_enterMarket(address(cEther)) == 0, "enterMarket-failed");
        super.mint();
    }

    //override
    /**
     * @dev Mint cToken for ERC20 and enter market on Compound
     * @notice onlyBToken can call this function, as `super.mint()` is protected with `onlyBToken` modifier
     */
    function mint(ICErc20 cToken, uint256 mintAmount) public returns (uint256) {
        require(_enterMarket(address(cToken)) == 0, "enterMarket-failed");
        uint256 result = super.mint(cToken, mintAmount);
        return result;
    }

    // EMERGENCY FUNCTIONS
    function emergencyCall(address payable target, bytes calldata data) external payable onlyAvatarOwner {
        uint first4Bytes = uint(uint8(data[0])) << 24 | uint(uint8(data[1])) << 16 | uint(uint8(data[2])) << 8 | uint(uint8(data[3])) << 0;
        bytes4 functionSig = bytes4(uint32(first4Bytes));

        require(quit || registry.whitelistedAvatarCalls(target, functionSig), "emergencyCall: not-listed");
        (bool succ, bytes memory err) = target.call.value(msg.value)(data);

        require(succ, string(err));
    }
}

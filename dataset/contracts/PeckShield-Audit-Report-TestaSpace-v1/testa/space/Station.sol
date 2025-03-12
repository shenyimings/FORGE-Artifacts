pragma solidity 0.5.16;
import "openzeppelin-solidity-2.3.0/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity-2.3.0/contracts/math/SafeMath.sol";
import "openzeppelin-solidity-2.3.0/contracts/math/Math.sol";
import "openzeppelin-solidity-2.3.0/contracts/utils/ReentrancyGuard.sol";
import "./StationConfig.sol";
import "./Orbit.sol";
import "./SafeToken.sol";
import "./interfaces/IUniverse.sol";


contract Station is ERC20, ReentrancyGuard, Ownable {
    /// @notice Libraries
    using SafeToken for address;
    using SafeMath for uint256;

    /// @notice Events
    event AddDebt(uint256 indexed id, uint256 debtShare);
    event RemoveDebt(uint256 indexed id, uint256 debtShare);
    event Launch(uint256 indexed id, uint256 loan);
    event Terminate(uint256 indexed id, address indexed killer, uint256 prize, uint256 left);

    string public name = "Interest ETH";
    string public symbol = "jETH";
    uint8 public decimals = 18;

    IUniverse public universe;

    struct Position {
        address orbit;
        address owner;
        uint256 debtShare;
        uint256 leverageVal;
    }

    StationConfig public config;
    mapping (uint256 => Position) public positions;
    uint256 public nextPositionID = 1;

    uint256 public glbDebtShare;
    uint256 public glbDebtVal;
    uint256 public lastAccrueTime;
    uint256 public starGate;

    /// @dev Require that the caller must be an EOA account to avoid flash loans.
    modifier onlyEOA() {
        require(msg.sender == tx.origin, "not eoa");
        _;
    }

    constructor(
        StationConfig _config, 
        IUniverse _universe
    ) public {
        config = _config;
        universe = _universe;
        lastAccrueTime = now;
    }

    /// @dev Add more debt to the global debt pool.
    modifier accrue(uint256 msgValue) {
        if (now > lastAccrueTime) {
            uint256 interest = pendingInterest(msgValue);
            uint256 toReserve = interest.mul(config.getStarGateBps()).div(10000);
            starGate = starGate.add(toReserve);
            glbDebtVal = glbDebtVal.add(interest);
            if(starGate > 0 && (universe.getHQBaseShare() > 0 || universe.getPlanetETHShare() > 0)){
                sendToOperator(starGate);
            }
            lastAccrueTime = now;
        }
        _;
    }

    function sendToOperator(uint256 _starGate) internal {
        uint256 hqBaseAmount = _starGate.mul(universe.getHQBaseShare()).div(10000);
        uint256 poolETHAmount = _starGate.mul(universe.getPlanetETHShare()).div(10000);

        SafeToken.safeTransferETH(universe.getHQBase(), hqBaseAmount);
        universe.depositETH.value(poolETHAmount)();
        starGate = starGate.sub(hqBaseAmount).sub(poolETHAmount);
    }

    /// @dev Return the pending interest that will be accrued in the next call.
    /// @param msgValue Balance value to subtract off address(this).balance when called from payable functions.
    function pendingInterest(uint256 msgValue) public view returns (uint256) {
        if (now > lastAccrueTime) {
            uint256 timePast = now.sub(lastAccrueTime);
            uint256 balance = address(this).balance.sub(msgValue);
            uint256 ratePerSec = config.getInterestRate(glbDebtVal, balance);
            return ratePerSec.mul(glbDebtVal).mul(timePast).div(1e18);
        } else {
            return 0;
        }
    }

    /// @dev Return the ETH debt value given the debt share. Be careful of unaccrued interests.
    /// @param debtShare The debt share to be converted.
    function debtShareToVal(uint256 debtShare) public view returns (uint256) {
        if (glbDebtShare == 0) return debtShare; // When there's no share, 1 share = 1 val.
        return debtShare.mul(glbDebtVal).div(glbDebtShare);
    }

    /// @dev Return the debt share for the given debt value. Be careful of unaccrued interests.
    /// @param debtVal The debt value to be converted.
    function debtValToShare(uint256 debtVal) public view returns (uint256) {
        if (glbDebtShare == 0) return debtVal; // When there's no share, 1 share = 1 val.
        return debtVal.mul(glbDebtShare).div(glbDebtVal);
    }

    /// @dev Return ETH value and debt of the given position. Be careful of unaccrued interests.
    /// @param id The position ID to query.
    function positionInfo(uint256 id) public view returns (uint256, uint256) {
        Position storage pos = positions[id];
        return (Orbit(pos.orbit).condition(id), debtShareToVal(pos.debtShare));
    }

    /// @dev Return the total ETH entitled to the token holders. Be careful of unaccrued interests.
    function totalETH() public view returns (uint256) {
        return address(this).balance.add(glbDebtVal).sub(starGate);
    }

    /// @dev Add more ETH to the bank. Hope to get some good returns.
    function deposit() external payable accrue(msg.value) nonReentrant {
        uint256 total = totalETH().sub(msg.value);
        uint256 share = total == 0 ? msg.value : msg.value.mul(totalSupply()).div(total);
        _mint(msg.sender, share);
    }

    /// @dev Withdraw ETH from the bank by burning the share tokens.
    function withdraw(uint256 share) external accrue(0) nonReentrant {
        uint256 amount = share.mul(totalETH()).div(totalSupply());
        _burn(msg.sender, share);
        uint256 profit = amount.sub(share);
        uint256 referralAmount = profit.mul(universe.getUniverseShare()).div(10000);
        address payable refferal = universe.getRefferral();
        (bool sent, bytes memory data) = refferal.call.value(referralAmount)("");
        require(sent, "Failed to transfer");
        SafeToken.safeTransferETH(msg.sender, amount.sub(referralAmount));
    }

    /// @dev Create a new farming position to unlock your yield farming potential.
    /// @param id The ID of the position to unlock the earning. Use ZERO for new position.
    /// @param orbit The address of the authorized orbit to work for this position.
    /// @param loan The amount of ETH to borrow from the pool.
    /// @param maxReturn The max amount of ETH to return to the pool.
    /// @param data The calldata to pass along to the orbit for more working context.
    function launch(uint256 id, address orbit, uint256 loan, uint256 maxReturn, uint256 leverageVal, bytes calldata data)
        external payable
        onlyEOA accrue(msg.value) nonReentrant
    {
        // 1. Sanity check the input position, or add a new position of ID is 0.
        if (id == 0) {
            id = nextPositionID++;
            positions[id].orbit = orbit;
            positions[id].owner = msg.sender;
            positions[id].leverageVal = leverageVal;
        } else {
            require(id < nextPositionID, "bad position id");
            require(positions[id].orbit == orbit, "bad position orbit");
            require(positions[id].owner == msg.sender, "not position owner");
        }
        emit Launch(id, loan);
        // 2. Make sure the orbit can accept more debt and remove the existing debt.
        require(config.isOrbit(orbit), "not a orbit");
        require(loan == 0 || config.acceptDebt(orbit), "orbit not accept more debt");
        uint256 debt = _removeDebt(id).add(loan);
        // 3. Perform the actual work, using a new scope to avoid stack-too-deep errors.
        uint256 back;
        {
            uint256 sendETH = msg.value.add(loan);
            require(sendETH <= address(this).balance, "insufficient ETH in the bank");
            uint256 beforeETH = address(this).balance.sub(sendETH);
            Orbit(orbit).launch.value(sendETH)(id, msg.sender, debt, data);
            back = address(this).balance.sub(beforeETH);
        }
        // 4. Check and update position debt.
        uint256 lessDebt = Math.min(debt, Math.min(back, maxReturn));
        debt = debt.sub(lessDebt);
        if (debt > 0) {
            require(debt >= config.minDebtSize(), "too small debt size");
            uint256 condition = Orbit(orbit).condition(id);
            uint256 launcher = config.launcher(orbit, debt);
            require(condition.mul(launcher) >= debt.mul(10000), "bad work factor");
            _addDebt(id, debt);
        }
        // 5. Return excess ETH back.
        if (back > lessDebt) SafeToken.safeTransferETH(msg.sender, back - lessDebt);
    }

    /// @dev Kill the given to the position. Liquidate it immediately if terminator condition is met.
    /// @param id The position ID to be killed.
    function terminate(uint256 id) external onlyEOA accrue(0) nonReentrant {
        // 1. Verify that the position is eligible for liquidation.
        Position storage pos = positions[id];
        require(pos.debtShare > 0, "no debt");
        uint256 debt = _removeDebt(id);
        uint256 condition = Orbit(pos.orbit).condition(id);
        uint256 terminator = config.terminator(pos.orbit, debt);
        require(condition.mul(terminator) < debt.mul(10000), "can't liquidate");
        // 2. Perform liquidation and compute the amount of ETH received.
        uint256 beforeETH = address(this).balance;
        Orbit(pos.orbit).destroy(id, msg.sender);
        uint256 back = address(this).balance.sub(beforeETH);
        uint256 prize = back.mul(config.getTerminateBps()).div(10000);
        uint256 rest = back.sub(prize);
        // 3. Clear position debt and return funds to liquidator and position owner.
        if (prize > 0) SafeToken.safeTransferETH(msg.sender, prize);
        uint256 left = rest > debt ? rest - debt : 0;
        if (left > 0) SafeToken.safeTransferETH(pos.owner, left);
        emit Terminate(id, msg.sender, prize, left);
    }

    /// @dev Internal function to add the given debt value to the given position.
    function _addDebt(uint256 id, uint256 debtVal) internal {
        Position storage pos = positions[id];
        uint256 debtShare = debtValToShare(debtVal);
        pos.debtShare = pos.debtShare.add(debtShare);
        glbDebtShare = glbDebtShare.add(debtShare);
        glbDebtVal = glbDebtVal.add(debtVal);
        emit AddDebt(id, debtShare);
    }

    /// @dev Internal function to clear the debt of the given position. Return the debt value.
    function _removeDebt(uint256 id) internal returns (uint256) {
        Position storage pos = positions[id];
        uint256 debtShare = pos.debtShare;
        if (debtShare > 0) {
            uint256 debtVal = debtShareToVal(debtShare);
            pos.debtShare = 0;
            glbDebtShare = glbDebtShare.sub(debtShare);
            glbDebtVal = glbDebtVal.sub(debtVal);
            emit RemoveDebt(id, debtShare);
            return debtVal;
        } else {
            return 0;
        }
    }

    /// @dev Update bank configuration to a new address. Must only be called by owner.
    /// @param _config The new configurator address.
    function updateConfig(StationConfig _config) external onlyOwner {
        config = _config;
    }

    /// @dev Withdraw ETH reserve for underwater positions to the given address.
    /// @param to The address to transfer ETH to.
    /// @param value The number of ETH tokens to withdraw. Must not exceed `starGate`.
    function withdrawReserve(address to, uint256 value) external onlyOwner nonReentrant {
        starGate = starGate.sub(value);
        SafeToken.safeTransferETH(to, value);
    }

    /// @dev Reduce ETH reserve, effectively giving them to the depositors.
    /// @param value The number of ETH reserve to reduce.
    function reduceReserve(uint256 value) external onlyOwner {
        starGate = starGate.sub(value);
    }

    /// @dev Recover ERC20 tokens that were accidentally sent to this smart contract.
    /// @param token The token contract. Can be anything. This contract should not hold ERC20 tokens.
    /// @param to The address to send the tokens to.
    /// @param value The number of tokens to transfer to `to`.
    function recover(address token, address to, uint256 value) external onlyOwner nonReentrant {
        token.safeTransfer(to, value);
    }

    /// @dev Fallback function to accept ETH. Orbits will send ETH back the pool.
    function() external payable {}
}

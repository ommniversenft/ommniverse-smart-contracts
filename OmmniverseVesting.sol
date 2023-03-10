// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OmmniverseTokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // cliff period in seconds
        uint256 cliff;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // whether or not the vesting is revocable
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
    }

    // address of the ERC20 token
    IERC20 public _token;
    bool public isInitialized;
    address[] vestingBeneficiaries;
    uint256 vestingSchedulesTotalAmount;
    mapping(address => VestingSchedule) vestingSchedules;

    //Events
    event Initialized(address indexed token);
    event Released(address indexed beneficiary, uint256 amount);
    event VestingCreated(address indexed beneficiary, uint256 amount);

    /**
     * @dev sets the vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    function initialize(address token_) public onlyOwner {
        require(token_ != address(0x0), "address can't be zero");
        require(!isInitialized, "already initialized");
        _token = IERC20(token_);
        isInitialized = true;
        emit Initialized(token_);
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start start time of the vesting period
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        uint256 _amount
    ) public onlyOwner {
        require(isInitialized, "not initialized");
        require(_beneficiary != address(0x0), "address can't be zero");
        require(
            this.getWithdrawableAmount() >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(
            _slicePeriodSeconds >= 1,
            "TokenVesting: slicePeriodSeconds must be >= 1"
        );
        require(
            vestingSchedules[_beneficiary].beneficiary == address(0),
            "A vesting schedule already exists for this address"
        );

        uint256 cliff = _start + _cliff;
        vestingSchedules[_beneficiary] = VestingSchedule(
            _beneficiary,
            _start,
            cliff,
            _duration,
            _slicePeriodSeconds,
            _amount,
            0
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
        vestingBeneficiaries.push(_beneficiary);
        emit VestingCreated(_beneficiary, _amount);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)) - (vestingSchedulesTotalAmount);
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getAvailableVestingAmount() public view returns (uint256) {
        require(isBeneficiary(msg.sender), "Not Beneficiary");
        VestingSchedule storage vestingSchedule = vestingSchedules[msg.sender];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     */
    function getToken() external view returns (address) {
        return address(_token);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(
        address _beneficiary
    ) public view returns (VestingSchedule memory) {
        return vestingSchedules[_beneficiary];
    }

    /**
     * @notice Release vested tokens.
     */
    function release() public nonReentrant {
        require(isBeneficiary(msg.sender), "Not Beneficiary");
        VestingSchedule storage vestingSchedule = vestingSchedules[msg.sender];

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount > 0, "Available vested amount is 0");
        vestingSchedule.released = vestingSchedule.released + (vestedAmount);
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        vestingSchedulesTotalAmount =
            vestingSchedulesTotalAmount -
            (vestedAmount);
        _token.safeTransfer(beneficiaryPayable, vestedAmount);
        emit Released(msg.sender, vestedAmount);
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(
        VestingSchedule memory vestingSchedule
    ) internal view returns (uint256) {
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.cliff)) {
            return 0;
        } else if (
            currentTime >= vestingSchedule.cliff + (vestingSchedule.duration)
        ) {
            return vestingSchedule.amountTotal - (vestingSchedule.released);
        } else {
            uint256 timeFromCliff = currentTime - (vestingSchedule.cliff);
            uint256 secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromCliff / (secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods * (secondsPerSlice);
            uint256 vestedAmount = (vestingSchedule.amountTotal * vestedSeconds) / vestingSchedule.duration;
            vestedAmount = vestedAmount - (vestingSchedule.released);
            return vestedAmount;
        }
    }

    function getCurrentTime() public view virtual returns (uint256) {
        return block.timestamp;
    }

    function isBeneficiary(address addr) public view returns (bool) {
        for (uint256 i = 0; i < vestingBeneficiaries.length; i++) {
            if (vestingBeneficiaries[i] == addr) {
                return true;
            }
        }
        return false;
    }
}

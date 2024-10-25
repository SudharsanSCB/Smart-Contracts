// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IErc20Token {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
    function transfer(address _recipient, uint256 _amount) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function approve(address _spender, uint256 _amount) external returns (bool);
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function setGreyList(address _addr, bool _frozen) external; // Include setGreyList
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract TokenPresale is OwnableUpgradeable {
    using SafeMath for uint256;

    IErc20Token public token;
    address public contractOwner;
    uint256 public totalTokens;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    uint256 public minimumPay;
    uint256 public bidId = 0;
    uint256 public lastDistributionTime;
    uint256 public distributionInterval = 2 weeks;
    uint256 public totalRewardsToDistribute;
    uint256 public totalRewardsDistributed;
    uint256 public tokenPrice;

    mapping(uint256 => address) public bidders;
    mapping(address => uint256) public bidAmounts;
    mapping(address => uint256) public userWithdrawableRewards;
    mapping(address => uint256) public userRewards;
    mapping(address => bool) public hasBid;

    event bidded(address indexed bidder, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);
    event WithdrawnReward(address indexed bidder, uint256 amount);
    event RewardsDistributed(uint256 totalTokens);
    event UnFreezeAcknowledgment(string acknowledgement);
    event RewardCalculated(uint256 rewardAmount);
    event RewardDistributed(uint256 amount);
      bool private initialized = false;

    modifier onlyDuringBiddingPeriod() {
        require(block.timestamp >= startTimestamp && block.timestamp <= endTimestamp, "Bidding period has ended");
        _;
    }

    modifier onlyAfterBiddingPeriod() {
        require(block.timestamp > endTimestamp, "Bidding period has not ended yet");
        _;
    }

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Ownable: caller is not the owner");
        _;
    }
     modifier notInitialized() {
        require(!initialized, "Contract already initialized");
        _;
    }

    function initialize(
        IErc20Token _token,
        address _contractOwner,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        uint256 _totalTokens,
        uint256 _minimumPay,
        uint256 _tokenPrice
    ) external initializer  notInitialized{
        require(_startTimestamp < _endTimestamp, "Invalid timestamps");
        token = _token;
        contractOwner = _contractOwner;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        totalTokens = _totalTokens * 1e9;
        minimumPay = _minimumPay;
        tokenPrice = _tokenPrice;
    }

    function migrateReward() public onlyContractOwner {
        require(token.balanceOf(msg.sender) >= totalTokens);
        token.transferFrom(msg.sender, address(this), totalTokens);
    }

    function bid() external payable onlyDuringBiddingPeriod {
        require(msg.value >= minimumPay, "Bid amount must be greater");
        bidAmounts[msg.sender] = bidAmounts[msg.sender].add(msg.value);
        if (!hasBid[msg.sender]) {
            bidId = bidId + 1;
            bidders[bidId] = msg.sender;
        }
        hasBid[msg.sender] = true;
        emit bidded(msg.sender, msg.value);
    }

    function withdraw() external onlyAfterBiddingPeriod onlyContractOwner {
        require(address(this).balance > 0, "No bidded amount to withdraw");
        uint256 amountToWithdraw = address(this).balance;
        payable(msg.sender).transfer(amountToWithdraw);
        emit Withdrawn(msg.sender, amountToWithdraw);
    }

    function withdrawUnsoldTokens() external onlyAfterBiddingPeriod onlyContractOwner {
        require(totalTokens > 0, "No tokens left to withdraw");
        token.transfer(msg.sender, totalTokens);
        totalTokens = 0;
        emit WithdrawnReward(msg.sender, totalTokens);
    }

    function distributeRewards() external onlyAfterBiddingPeriod onlyContractOwner {
        require(totalTokens > 0, "No tokens to distribute");
        uint256 totalBidded = address(this).balance;
        require(totalBidded > 0, "No Bidded Ether to distribute");
        require(block.timestamp >= lastDistributionTime + distributionInterval, "Tokens locked for 2 weeks");

        for (uint256 i = 1; i <= bidId; i++) {
            address bidder = bidders[i];
            uint256 initialRewardAmount = (bidAmounts[bidder].mul(tokenPrice)).div(1e18);
            uint256 immediateReward = (initialRewardAmount.mul(5)).div(100);
            userWithdrawableRewards[bidder] = immediateReward;
            userRewards[bidder] = initialRewardAmount.sub(immediateReward); // Lock 95%
            // Update last distribution time for this bidder
            lastDistributionTime = block.timestamp;
        }
    }

    // Function to allow users to withdraw their Reward
    function withdrawReward() external onlyAfterBiddingPeriod {
        if (userRewards[msg.sender] == 0) {
            emit RewardsDistributed(totalTokens);
            userWithdrawableRewards[msg.sender] = 0; // Reset totalTokens after all rewards are fully distributed
        }
        uint256 _rewardAmount = userWithdrawableRewards[msg.sender];
        require(_rewardAmount > 0, "No reward amount to withdraw");
        require(totalTokens >= _rewardAmount, "Insufficient tokens in presale contract");
        token.transfer(msg.sender, _rewardAmount);
        totalTokens -= _rewardAmount;
        emit WithdrawnReward(msg.sender, _rewardAmount);
        userWithdrawableRewards[msg.sender] = 0;
    }

    function calculateRemainingReward(address _bidder) internal view returns (uint256) {
        return totalTokens.sub(userRewards[_bidder]);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTokens() external view returns (uint256) {
        return totalTokens;
    }

    function getRewardAmount(address _bidder) external view returns (uint256) {
        return userRewards[_bidder];
    }

    function getBiddedAmount(address _bidder) external view returns (uint256) {
        return bidAmounts[_bidder];
    }

    function getStartTimestamp() external view returns (uint256) {
        return startTimestamp;
    }

    function getEndTimestamp() external view returns (uint256) {
        return endTimestamp;
    }

    function getContractOwner() external view returns (address) {
        return contractOwner;
    }

    function reSetter(
        IErc20Token _token,
        address _contractOwner,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        uint256 _totalTokens,
        uint256 _minimumPay
    ) public onlyContractOwner {
        require(_startTimestamp < _endTimestamp, "Invalid timestamps");
        token = _token;
        contractOwner = _contractOwner;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        totalTokens = _totalTokens * 1e9;
        minimumPay = _minimumPay;
    }

    function reset_lastDistributionTime(uint256 _lastDistributionTime) public onlyContractOwner {
        lastDistributionTime = _lastDistributionTime;
    }

    function reset_minimumPay(uint256 _minimumPay) public onlyContractOwner {
        minimumPay = _minimumPay;
    }

    function reset_endTimestamp(uint256 _endTimestamp) public onlyContractOwner {
        endTimestamp = _endTimestamp;
    }

    function reset_tokenContractAddress(IErc20Token _token) public onlyContractOwner {
        token = _token;
    }

    function reset_tokenPrice(uint256 _tokenPrice) public onlyContractOwner {
        tokenPrice = _tokenPrice;
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import { FrontDoorStructs } from "./DataModel.sol";
import { Errors } from "./Errors.sol";

contract Recruitment {
  event PercentagesCompleted(address indexed sender, uint8 month1RefundPct, uint8 month2RefundPct, uint8 month3RefundPct);
  event DepositCompleted(address indexed sender, uint256 amount);
  address owner;
  mapping(bytes32 => address) public whitelistedTokens;
  mapping(bytes32 => uint8) public whitelistedTokenDecimals;
  mapping(address => mapping(bytes32 => uint256)) public accountBalances;
  mapping(address => uint8[3][]) public accountMonthlyRefundPcts;
  mapping(address => uint8[]) public accountCompleteDeposits;
  mapping(address => uint)public balances;
  mapping(address => string[])public referredEmails;
  mapping(address => FrontDoorStructs.Candidate) public candidateList;
  mapping(address => FrontDoorStructs.Referee) public refereeList;
  mapping(address => FrontDoorStructs.Referrer) public referrerList;
  mapping(uint256 => FrontDoorStructs.Job) public jobList;
  mapping(address => uint256[]) public referralIndex;
  mapping(uint256 => FrontDoorStructs.Referral) public referralList;
  using Counters for Counters.Counter;
  Counters.Counter private jobIdCounter;
  Counters.Counter private referralCounter;
  uint256 initialAmountUSD = 1000;
  constructor() {
    owner = msg.sender;
  }

  function whitelistToken(bytes32 symbol, address tokenAddress, uint8 decimals) external {
    require(msg.sender == owner, 'This function is not public');
    whitelistedTokenDecimals[symbol] = decimals;
    whitelistedTokens[symbol] = tokenAddress;
  }

  function getWhitelistedTokenAddresses(bytes32 token) external view returns(address) {
    return whitelistedTokens[token];
  }

  function getWhitelistedTokenDecimals(bytes32 token) external view returns(uint8) {
    return whitelistedTokenDecimals[token];
  }

  function getAccountCompleteDeposits() external view returns(uint8[] memory) {
    return accountCompleteDeposits[msg.sender];
  }

  function getAccountMonthlyRefundPcts() external view returns(uint8[3][] memory) {
    return accountMonthlyRefundPcts[msg.sender];
  }

  function setPercentages(
    uint8 month1RefundPct
    ,uint8 month2RefundPct
    ,uint8 month3RefundPct
  ) external {
    require(month1RefundPct >= 0 && month1RefundPct <= 100, "Month 1 percentage between 0 and 100!");
    require(month2RefundPct >= 0 && month2RefundPct <= 100, "Month 2 percentage between 0 and 100!");
    require(month3RefundPct >= 0 && month3RefundPct <= 100, "Month 3 percentage between 0 and 100!");
    accountMonthlyRefundPcts[msg.sender].push([month1RefundPct, month2RefundPct, month3RefundPct]);
    emit PercentagesCompleted(msg.sender, month1RefundPct, month2RefundPct, month3RefundPct);
  }

  function setFinalDeposit(
    bytes32 symbol,
    uint256 amount,
    uint8 index
  ) external {
    require(ERC20(whitelistedTokens[symbol]).allowance(msg.sender, address(this)) >= amount, "Allowance does reach amount to be treansferred!");
    require(accountMonthlyRefundPcts[msg.sender].length > index, "Initial deposit index does not match!");
    accountBalances[msg.sender][symbol] += amount;
    ERC20(whitelistedTokens[symbol]).transferFrom(msg.sender, address(this), amount);
    accountCompleteDeposits[msg.sender].push(index);
    emit DepositCompleted(msg.sender, amount);
  }

  function setEmailReferrals(string memory email) external {
    referredEmails[msg.sender].push(email);
  }

  function getEmailReferrals() external view returns(string[] memory) {
    return referredEmails[msg.sender];
  }

  /**
    * @notice Registers a candidate with their email
    * @param email The email of the candidate to be registered.
  */
  function registerCandidate(string memory email) external {
    FrontDoorStructs.Candidate memory candidate = FrontDoorStructs.Candidate(msg.sender, email,0);
    candidateList[msg.sender] = candidate;
  }

  /**
    * @notice Getter function of Candidate.
    * @param wallet The wallet address of a candidate to be fetched from the mapping
    * @return Candidate The type of FrontDoorStruct.Candidate 
  */
  function getCandidate(address wallet) external view returns(FrontDoorStructs.Candidate memory) {
    return candidateList[wallet];
  }

  /**
    * @notice Registers a referrer with their email
    * @param email The email of the referrer to be registered.
  */
  function registerReferrer(string memory email) external {
    FrontDoorStructs.Referrer memory referrer = FrontDoorStructs.Referrer(msg.sender, email, 0);
    referrerList[msg.sender] = referrer;
  }

  /**
    * @notice Getter function of Referrer.
    * @param wallet The wallet address of a referrer to be fetched from the mapping
    * @return Referrer The type of FrontDoorStruct.Referrer 
  */
  function getReferrer(address wallet) external view returns(FrontDoorStructs.Referrer memory) {
    return referrerList[wallet];
  }

  /**
    * @notice Registers a referee with their email
    * @param email The email of the referee to be registered.
  */
  function registerReferee(string memory email) external {
    FrontDoorStructs.Referee memory referee = FrontDoorStructs.Referee(msg.sender, email,keccak256(abi.encodePacked(email)), 0);
    refereeList[msg.sender] = referee;
  }

  /**
    * @notice Getter function of Referee.
    * @param wallet The wallet address of a referee to be fetched from the mapping
    * @return Referee The type of FrontDoorStruct.Referee 
  */
  function getReferee(address wallet) external view returns(FrontDoorStructs.Referee memory) {
    return refereeList[wallet];
  }

  /**
    * @notice Registers a job
    * @param bounty The amount of bounty set by the job poster.
    * @param maxSalary The amount of maximum salary.
    * @param minSalary The amount of minimum salary.
    * @param companyName The name of company.
    * @param location The location of the company.
    * @param role The role for the job.
    * @param jobURL The web URL of the job description.
  */
  function registerJob(uint256 bounty, uint256 maxSalary, uint256 minSalary, string memory companyName, string memory location, string memory role, string memory jobURL) external {
    uint256 jobId = jobIdCounter.current();
    FrontDoorStructs.Job memory job = FrontDoorStructs.Job(jobId, bounty, maxSalary, minSalary, companyName, location, role, jobURL);
    jobList[jobId] = job;
    jobIdCounter.increment();
  }

  /**
    * @notice Getter function of Job.
    * @param jobId The ID of a job to fetch from the mapping
    * @return Job The type of FrontDoorStruct.Job 
  */
  function getJob(uint256 jobId) external view returns(FrontDoorStructs.Job memory){
    return jobList[jobId];
  }

  /**
    * @notice Registers a referral
    * @param jobId The job ID already registered with the contract.
    * @param refereeMail The email of the referee.
  */
  function registerReferral(uint256 jobId, string memory refereeMail) external {
    FrontDoorStructs.Referee memory referee; // = refereeList[refereeWallet];
    FrontDoorStructs.Referrer memory referrer = referrerList[msg.sender];
    FrontDoorStructs.Job memory job = jobList[jobId];

    
    referee.email =  refereeMail;
    referee.emailHash = keccak256(abi.encodePacked(refereeMail));
    FrontDoorStructs.Referral memory referral = FrontDoorStructs.Referral(referralCounter.current(), false, referrer, referee, job);

    referralIndex[msg.sender].push(referralCounter.current());
    referralList[referralCounter.current()] = referral;
    referralCounter.increment();

  }

  /**
    * @notice Confirmation of a referral by the msg.sender (if the msg.sender is the referee)
    * @param refId The referral ID already recorded in the smart contract.
    * @param email The email address of the referee.
  */
  function confirmReferral(uint256 refId, string memory email) external {
    
    bytes32 emailHash = keccak256(abi.encodePacked(email));
    FrontDoorStructs.Referral memory referral = referralList[refId];

    //if (referral.referee.wallet != msg.sender) revert Errors.SenderIsNotReferee(); // The msg.sender should be the referee.
    if (referral.referee.emailHash != emailHash) revert Errors.SenderIsNotReferee(); // The msg.sender should be the referee.
    referral.confirmed = true;
    referralList[refId] = referral;
  }

  /**
    * @notice Getter function of Referral IDs of the msg.sender.
    * @return uint256[] An array of uint256 with all the referral ids of msg.sender
  */
  function getReferralIDs() external view returns(uint256[] memory){
    return referralIndex[msg.sender];
  }

  /**
    * @notice Getter function of Referral.
    * @param refId The referral ID already recorded in the smart contract.
    * @return Referral The type of FrontDoorStruct.Referral
  */
  function getReferral(uint256 refId) external view returns(FrontDoorStructs.Referral memory) {
    return referralList[refId];
  }


  // function withdrawTokens(bytes32 symbol, uint256 amount) external {
  //   // to be continued...
  //   require(msg.sender == owner, 'Only owner can withdraw!');
  //   require(ERC20(whitelistedTokens[symbol]).balanceOf(msg.sender) > amount, 'Not enough balances!');
  //   accountBalances[msg.sender][symbol] -= amount;
  //   ERC20(whitelistedTokens[symbol]).transfer(msg.sender, amount);
  // }
}
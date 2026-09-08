%% =========================================================
% PROJECT 1: PORTFOLIO OPTIMISATION AND PRICING INTEREST RATE
% USING A SCORING MODEL
%% =========================================================

clearvars -except DataProjScoreCard ActualPortfolioData
clc;
close all;

%% =========================================================
% 1. DEVELOP A SCORING MODEL
%% =========================================================

% We use only the useful historical columns for training:
% Age, ResidentialStatus, EmploymentStatus, Income, Default.
% We do not use ID or PD because:
% ID is only an identifier.
% PD is already a probability, so using it would be data leakage.

TrainingData = DataProjScoreCard(:, {'Age','ResidentialStatus','EmploymentStatus','Income','Default'});

% Default = 0 means good client.
% Default = 1 means bad/defaulted client.
sc = creditscorecard(TrainingData, ...
                     'ResponseVar','Default', ...
                     'GoodLabel',0);

disp(sc);

%% =========================================================
% 2. BIN THE DATA AND SHOW WOE USING bininfo AND plotbins
%% =========================================================

sc = autobinning(sc);

%% ---------- AGE ----------
[bi1, cp1] = bininfo(sc, 'Age');
disp('Binning Information for Age');
disp(bi1);
plotbins(sc, 'Age');

%% ---------- INCOME ----------
[bi2, cp2] = bininfo(sc, 'Income');
disp('Binning Information for Income');
disp(bi2);
plotbins(sc, 'Income');

%% ---------- RESIDENTIAL STATUS ----------
[bi3, cp3] = bininfo(sc, 'ResidentialStatus');
disp('Binning Information for ResidentialStatus');
disp(bi3);
plotbins(sc, 'ResidentialStatus');

%% ---------- EMPLOYMENT STATUS ----------
[bi4, cp4] = bininfo(sc, 'EmploymentStatus');
disp('Binning Information for EmploymentStatus');
disp(bi4);
plotbins(sc, 'EmploymentStatus');

%% =========================================================
% 3. FIT A LOGISTIC REGRESSION FOR THE MODEL
%% =========================================================

sc = fitmodel(sc);

disp(sc);

%% =========================================================
% 4. DISPLAY THE UNSCALED POINTS
%% =========================================================

points = displaypoints(sc);

disp('Unscaled Points');
disp(points);

%% =========================================================
% 5. DISPLAY PORTFOLIO SCORES BETWEEN 0 AND 100
%% =========================================================

sc = formatpoints(sc, 'WorstAndBestScores', [0 100]);

Scores = score(sc, ActualPortfolioData);

disp('Portfolio Scores');
disp(Scores);

% Chart: portfolio scores
figure;
bar(Scores);
xlabel('Client Number');
ylabel('Score');
title('Portfolio Scores Between 0 and 100');
grid on;

%% =========================================================
% 6. PLOT THE ROC CURVE USING HISTORICAL DATA
%% =========================================================

% validatemodel automatically creates the ROC chart.
figure;
[Stats, T] = validatemodel(sc, 'Plot', 'ROC');

disp('Validation Statistics');
disp(Stats);

disp('ROC Table');
disp(T);

% Add AUC value on the ROC chart
% aucValue = Stats.Value(strcmp(Stats.Measure, 'Area under ROC curve'));

% text(0.60, 0.20, sprintf('AUC = %.4f', aucValue), ...
%      'FontSize', 13, ...
%      'FontWeight', 'bold', ...
%      'Color', 'red', ...
%      'Units', 'normalized');

title('ROC Curve using Historical Data');

%% =========================================================
% 7. DISPLAY PROBABILITY OF DEFAULT OF THE PORTFOLIO
%% =========================================================

PDs = probdefault(sc, ActualPortfolioData);

disp('Probability of Default for Portfolio Clients');
disp(PDs);

% Chart: probability of default per client
figure;
bar(PDs);
xlabel('Client Number');
ylabel('Probability of Default');
title('Probability of Default for Each Portfolio Client');
grid on;

% Chart: score vs probability of default
figure;
scatter(Scores, PDs, 80, 'filled');
xlabel('Score');
ylabel('Probability of Default');
title('Score vs Probability of Default');
grid on;

%% =========================================================
% 8. FIND THE OPTIMAL SCORE
%% =========================================================

% We choose the score that maximizes the number of correct predictions.

% OCO = Optimal Cut-Off Score
% In the course, the OCO is taken as the KS score from validatemodel.

optimalScore = Stats.Value(strcmp(Stats.Measure, 'KS score'));

disp('Optimal Cut-Off Score');
disp(optimalScore);

%% =========================================================
% 9. SELECT THE GOOD CLIENTS
%% =========================================================

% Since higher score means lower risk, we select clients with:
% Score >= optimalScore
selectedIdx = Scores >= optimalScore;

disp('Selected Clients Index');
disp(selectedIdx);

% Keep only accepted clients
selectedClients = ActualPortfolioData(selectedIdx, :);

% Add the 0/1 selected index
selectedClients.SelectedIdx = selectedIdx(selectedIdx);

% Add the model probability of default
selectedClients.ModelPD = PDs(selectedIdx);

% Move SelectedIdx before ID
selectedClients = movevars(selectedClients, 'SelectedIdx', 'Before', 'ID');

disp('Selected Clients Decision Table');
disp(selectedClients);

%% =========================================================
% 10. EXPECTED LOSS GIVEN RECOVERY RATE OF 60%
%% =========================================================

loanAmount = 100000;
recoveryRate = 0.60;
LGD = 1 - recoveryRate;

selectedPDs = PDs(selectedIdx);

expectedLosses = selectedPDs * loanAmount * LGD;

totalExpectedLoss = sum(expectedLosses);

disp('Selected PDs');
disp(selectedPDs);

ExpectedLossTable = table(selectedClients.ID, expectedLosses, ...
    'VariableNames', {'ClientID','ExpectedLoss'});

disp('Expected Loss Table');
disp(ExpectedLossTable);

fprintf('Total Expected Loss: %.6f\n', totalExpectedLoss);

% Chart: expected loss per selected client
figure;
bar(expectedLosses);
xlabel('Selected Client Number');
ylabel('Expected Loss');
title('Expected Loss for Selected Clients');
grid on;

%% =========================================================
% 11. PRICE THE MINIMUM INTEREST RATE
%% =========================================================

% Minimum break-even interest rate:
% r = (PD * LGD) / (1 - PD)

minInterestRates = (selectedPDs * LGD) ./ (1 - selectedPDs);

MinInterestRateTable = table(selectedClients.ID, minInterestRates, ...
    'VariableNames', {'ClientID','MinimumInterestRate'});

disp('Minimum Interest Rate Table');
disp(MinInterestRateTable);

% Chart: minimum interest rate per selected client
figure;
bar(minInterestRates);
xlabel('Selected Client Number');
ylabel('Minimum Interest Rate');
title('Minimum Interest Rate for Selected Clients');
grid on;

%% =========================================================
% 12. DISPLAY FINAL SELECTED CLIENTS WITH PD, EL, AND RATE
%% =========================================================

selectedClients.PD = selectedPDs;
selectedClients.ExpectedLoss = expectedLosses;
selectedClients.MinInterestRate = minInterestRates;

disp('Final Selected Clients');
disp(selectedClients);

%% =========================================================
% 13. FINAL SUMMARY
%% =========================================================

fprintf('\n========================================\n');
fprintf('FINAL PORTFOLIO SUMMARY\n');
fprintf('========================================\n');
fprintf('Optimal Score          : %.4f\n', optimalScore);
fprintf('Number of clients      : %d / %d\n', sum(selectedIdx), height(ActualPortfolioData));
fprintf('Total Nominal Amount   : $%.0f\n', sum(selectedIdx) * loanAmount);
fprintf('Total Expected Loss    : $%.2f\n', totalExpectedLoss);
fprintf('Average PD             : %.4f (%.2f%%)\n', mean(selectedPDs), mean(selectedPDs) * 100);
fprintf('Average Min Rate       : %.4f (%.2f%%)\n', mean(minInterestRates), mean(minInterestRates) * 100);
fprintf('========================================\n');

%% =========================================================
% 14. FINAL DASHBOARD
%% =========================================================

figure;

subplot(3,1,1);
bar(Scores);
hold on;
yline(optimalScore, '--', 'LineWidth', 2);
xlabel('Client Number');
ylabel('Score');
title('Portfolio Scores');
grid on;

subplot(3,1,2);
bar(PDs);
xlabel('Client Number');
ylabel('PD');
title('Probability of Default');
grid on;

subplot(3,1,3);
bar(minInterestRates);
xlabel('Selected Client Number');
ylabel('Minimum Interest Rate');
title('Minimum Interest Rate for Selected Clients');
grid on;

sgtitle('Final Portfolio Dashboard');
import 'package:nex_core/nex_core.dart';
import '../../l10n/app_localizations.dart';

String cycleFlowLabel(AppLocalizations l, CycleFlow value) =>
    [l.cycleSpotting, l.cycleLight, l.cycleMedium, l.cycleHeavy][value.index];
String cycleMoodLabel(AppLocalizations l, CycleMood value) => [
  l.cycleLow,
  l.cycleSensitive,
  l.cycleCalm,
  l.cycleGood,
  l.cycleGreat,
][value.index];
String cycleSymptomLabel(AppLocalizations l, CycleSymptom value) => [
  l.cycleCramps,
  l.cycleHeadache,
  l.cycleBackPain,
  l.cycleBloating,
  l.cycleBreastTenderness,
  l.cycleAcne,
  l.cycleNausea,
  l.cycleFatigue,
  l.cycleCravings,
  l.cycleInsomnia,
  l.cycleDizziness,
  l.cycleDischarge,
][value.index];
String cycleStageLabel(AppLocalizations l, CycleStage value) => [
  l.cyclePeriodStage,
  l.cycleFollicular,
  l.cycleFertile,
  l.cycleLuteal,
][value.index];

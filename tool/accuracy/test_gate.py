import unittest

from gate import evaluate


def results(correct=95, bars=100):
    row = dict.fromkeys(('bars', 'bars_exact', 'chords', 'chord_errors', 'syllables', 'lyric_errors',
                         'onset_bars', 'onset_wrong', 'sign_bars', 'sign_wrong', 'merged_bars', 'missing_bars'), 0)
    row.update(bars=bars, bars_exact=correct)
    return {'sample': {'ai': row}}


class AccuracyGateTest(unittest.TestCase):
    def test_below_95_does_not_pass(self):
        self.assertFalse(evaluate(results(94))['coarse_target_met'])

    def test_unmeasured_pitch_cannot_be_called_release_ready(self):
        result = evaluate(results())
        self.assertTrue(result['coarse_target_met'])
        self.assertFalse(result['release_ready'])
        self.assertEqual(result['pitch_accuracy'], 'not_measured')

    def test_missing_songs_fail_even_if_the_rest_are_perfect(self):
        data = results(100)
        data['missing'] = {'ai': None}
        self.assertFalse(evaluate(data)['coarse_target_met'])

    def test_empty_data_never_means_100_percent(self):
        self.assertFalse(evaluate({})['coarse_target_met'])

    def test_766_bars_need_728_correct(self):
        result = evaluate(results(512, 766))
        self.assertEqual(result['required_correct_bars'], 728)
        self.assertEqual(result['additional_correct_bars_needed'], 216)

    def test_invalid_targets_are_rejected(self):
        for target in (0, -1, 101):
            with self.assertRaises(ValueError):
                evaluate(results(), target)


if __name__ == '__main__':
    unittest.main()

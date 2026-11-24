import 'package:flutter_test/flutter_test.dart';

import 'package:compozy_app/features/automations/domain/cron_translator.dart';

void main() {
  group('CronTranslator', () {
    test('translates daily schedule at 09:00 (0 9 * * *)', () {
      expect(CronTranslator.translate('0 9 * * *'), 'Every day at 09:00');
    });

    test('translates daily schedule at 08:00 (0 8 * * *)', () {
      expect(CronTranslator.translate('0 8 * * *'), 'Every day at 08:00');
    });

    test('translates weekday schedule at 09:00 (0 9 * * 1-5)', () {
      expect(CronTranslator.translate('0 9 * * 1-5'), 'Every weekday at 09:00');
    });

    test('translates single day schedule on Monday (0 10 * * 1)', () {
      expect(CronTranslator.translate('0 10 * * 1'), 'Every Monday at 10:00');
    });

    test('translates single day schedule on Friday (0 16 * * 5)', () {
      expect(CronTranslator.translate('0 16 * * 5'), 'Every Friday at 16:00');
    });

    test('translates every 15 minutes (*/15 * * * *)', () {
      expect(CronTranslator.translate('*/15 * * * *'), 'Every 15 minutes');
    });

    test('translates every 5 minutes (*/5 * * * *)', () {
      expect(CronTranslator.translate('*/5 * * * *'), 'Every 5 minutes');
    });

    test('translates hourly schedule at minute 0 (0 * * * *)', () {
      expect(CronTranslator.translate('0 * * * *'), 'Every hour');
    });

    test('translates every 2 hours at minute 0 (0 */2 * * *)', () {
      expect(CronTranslator.translate('0 */2 * * *'), 'Every 2 hours');
    });

    test('translates weekend schedule at 14:30 (30 14 * * 0,6)', () {
      expect(CronTranslator.translate('30 14 * * 0,6'), 'Every weekend at 14:30');
    });

    test('falls back to raw expression for untranslatable complex cron', () {
      const complexExpr = '23 0-20/2 * * *';
      expect(CronTranslator.translate(complexExpr), complexExpr);
    });

    test('falls back to raw expression for irregular cron strings', () {
      const invalidExpr = 'not-a-cron-expression';
      expect(CronTranslator.translate(invalidExpr), invalidExpr);
    });

    test('handles null and empty strings gracefully', () {
      expect(CronTranslator.translate(null), '');
      expect(CronTranslator.translate(''), '');
      expect(CronTranslator.translate('   '), '');
    });
  });
}

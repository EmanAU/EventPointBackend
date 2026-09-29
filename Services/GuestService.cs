using DAL;
using IServices;
using Models.Guest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class GuestService : IGuestService
    {
        public async Task<ApproveGuestResponse> ApproveGuestAsync(ApproveGuestRequest request)
        {
            return await GuestsDAL.ApproveGuestAsync(request);
        }

        public async Task<PromoteAdminResponse> PromoteAdminAsync(PromoteAdminRequest request)
        {
            return await GuestsDAL.PromoteAdminAsync(request);
        }

        public async Task<IEnumerable<ApprovedGuestResponse>> GetApprovedGuestsAsync(GetApprovedGuestsRequest request)
        {
            return await GuestsDAL.GetApprovedGuestsAsync(request);
        }

        public async Task<RemoveGuestResponse> RemoveGuestAsync(RemoveGuestRequest request)
        {
            return await GuestsDAL.RemoveGuestAsync(request);
        }

        public async Task<DemoteAdminResponse> DemoteAdminAsync(DemoteAdminRequest request)
        {
            return await GuestsDAL.DemoteAdminAsync(request);
        }
    }
}
